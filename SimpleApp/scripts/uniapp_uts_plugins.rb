# frozen_string_literal: true

require 'fileutils'
require 'json'

module UniAppUTSPlugins
  module_function

  def prepare!(plugins_root, sdk_path:, values: {})
    plugins_root = File.expand_path(plugins_root)
    sdk_path = File.expand_path(sdk_path)
    generated_root = File.join(plugins_root, '.generated')
    support_root = File.join(sdk_path, 'SDK', 'UTS')
    return [] unless Dir.exist?(plugins_root)

    FileUtils.rm_rf(generated_root)
    FileUtils.mkdir_p(generated_root)

    Dir.children(plugins_root).sort.filter_map do |plugin_name|
      next if plugin_name.start_with?('.')

      app_ios = find_app_ios(File.join(plugins_root, plugin_name))
      next unless Dir.exist?(app_ios)

      pod_name = "unimodule#{camelize(plugin_name)}"
      pod_path = File.join(generated_root, pod_name)
      FileUtils.mkdir_p(pod_path)

      copy_support_files(support_root, pod_path)
      copy_plugin_files(app_ios, pod_path)

      config = substitute_placeholders(read_json(File.join(app_ios, 'config.json')), plugin_values(values, plugin_name), plugin_name)
      write_runtime_config(config, File.join(pod_path, 'config.json'))
      write_podspec(pod_path, pod_name, plugin_name, config)

      {
        name: plugin_name,
        pod_name: pod_name,
        pod_path: pod_path,
        app_ios: app_ios,
        config: config,
        info_plist: File.join(app_ios, 'Info.plist'),
        entitlements: File.join(app_ios, 'UTS.entitlements')
      }
    end
  end

  def camelize(name)
    name.split(/[^A-Za-z0-9]+/).reject(&:empty?).map { |part| part[0].upcase + part[1..] }.join
  end

  def find_app_ios(plugin_root)
    candidates = [
      File.join(plugin_root, 'app-ios'),
      File.join(plugin_root, 'utssdk', 'app-ios')
    ]
    candidates.find { |path| Dir.exist?(path) } || candidates.first
  end

  def copy_support_files(support_root, pod_path)
    %w[DCloudUTSConfig.h DCloudUTSConfig.m UTSCPP.h UTSCPP.mm].each do |file|
      source = File.join(support_root, file)
      FileUtils.cp(source, pod_path) if File.exist?(source)
    end
  end

  def copy_plugin_files(app_ios, pod_path)
    %w[src Frameworks Libs Resources].each do |name|
      source = File.join(app_ios, name)
      FileUtils.cp_r(source, File.join(pod_path, name)) if Dir.exist?(source)
    end

    privacy = File.join(app_ios, 'PrivacyInfo.xcprivacy')
    FileUtils.cp(privacy, pod_path) if File.exist?(privacy)

    copy_flat_binaries(app_ios, pod_path)
  end

  def copy_flat_binaries(app_ios, pod_path)
    has_subdirs = %w[src Frameworks Libs].any? { |name| Dir.exist?(File.join(app_ios, name)) }
    return if has_subdirs

    headers = File.join(app_ios, 'Headers')
    modules = File.join(app_ios, 'Modules')
    has_headers = Dir.exist?(headers)
    has_modules = Dir.exist?(modules)
    has_binary = Dir.children(app_ios).any? { |c| File.file?(File.join(app_ios, c)) && !c.start_with?('.') && File.extname(c) != '.bundle' && c != 'Info.plist' && c != 'PrivacyInfo.xcprivacy' }

    if has_binary || has_headers || has_modules
      framework_name = File.basename(File.dirname(app_ios))
      framework_dir = File.join(pod_path, 'Frameworks', framework_name)
      FileUtils.mkdir_p(framework_dir)

      FileUtils.cp_r(headers, File.join(framework_dir, 'Headers')) if has_headers
      FileUtils.cp_r(modules, File.join(framework_dir, 'Modules')) if has_modules

      info_plist = File.join(app_ios, 'Info.plist')
      FileUtils.cp(info_plist, framework_dir) if File.exist?(info_plist)
    end

    Dir.children(app_ios).each do |child|
      source = File.join(app_ios, child)
      next if child.start_with?('.') || child == 'Info.plist' || child == 'PrivacyInfo.xcprivacy'

      case File.extname(child)
      when '.bundle'
        resource_dir = File.join(pod_path, 'Resources')
        FileUtils.mkdir_p(resource_dir)
        FileUtils.cp_r(source, File.join(resource_dir, child))
      else
        FileUtils.cp(source, File.join(framework_dir, child)) if has_binary && File.file?(source)
      end
    end
  end

  def read_json(path)
    return {} unless File.exist?(path)

    JSON.parse(File.read(path))
  rescue JSON::ParserError => e
    warn "[UniAppUTSPlugins] Failed to parse #{path}: #{e.message}"
    {}
  end

  def plugin_values(values, plugin_name)
    values[plugin_name] || values[plugin_name.to_sym] || {}
  end

  def substitute_placeholders(object, values, plugin_name)
    case object
    when Hash
      object.transform_values { |value| substitute_placeholders(value, values, plugin_name) }
    when Array
      object.map { |value| substitute_placeholders(value, values, plugin_name) }
    when String
      object.gsub(/\{\$([A-Za-z0-9_]+)\}/) do
        key = Regexp.last_match(1)
        value = values[key] || values[key.to_sym]
        if present?(value)
          value.to_s
        else
          warn "[UniAppUTSPlugins] Missing value for #{plugin_name}.#{key}; keep placeholder #{Regexp.last_match(0)}."
          Regexp.last_match(0)
        end
      end
    else
      object
    end
  end

  def write_runtime_config(config, path)
    runtime = {}
    runtime['hooksClass'] = config['hooksClass'] if present?(config['hooksClass'])
    runtime['provider'] = config['provider'] if present?(config['provider'])
    runtime['providers'] = config['providers'] if present?(config['providers'])
    runtime['components'] = config['components'] if present?(config['components'])
    File.write(path, JSON.pretty_generate(runtime))
  end

  def write_podspec(pod_path, pod_name, plugin_name, config)
    frameworks = array_config(config, 'frameworks').map { |name| name.sub(/\.framework\z/, '') }
    libraries = array_config(config, 'libraries')
    dependencies = normalize_dependencies(config['dependencies-pods'])
    deployment_target = config['deploymentTarget'].to_s.empty? ? '13.0' : config['deploymentTarget'].to_s

    lines = []
    lines << 'Pod::Spec.new do |s|'
    lines << "  s.name = '#{pod_name}'"
    lines << "  s.version = '1.0.0'"
    lines << "  s.summary = 'uni-app UTS plugin #{plugin_name}.'"
    lines << "  s.authors = 'DCloud'"
    lines << "  s.license = { :type => 'MIT' }"
    lines << "  s.homepage = 'https://uniapp.dcloud.net.cn'"
    lines << "  s.platform = :ios, '#{deployment_target}'"
    has_src = Dir.exist?(File.join(pod_path, 'src'))
    lines << "  s.source = { :git => '' }"
    if has_src
      lines << "  s.source_files = ['src/**/*.{h,m,mm,swift,c,cc,cpp}', 'DCloudUTSConfig.{h,m}', 'UTSCPP.{h,mm}']"
    else
      lines << "  s.source_files = 'DCloudUTSConfig.h'"
    end
    lines.concat(resource_lines(pod_path))
    lines << "  s.vendored_frameworks = 'Frameworks/**/*.{framework,xcframework}'"
    lines << "  s.vendored_libraries = 'Libs/**/*.a'"
    lines << "  s.frameworks = #{frameworks.inspect}" unless frameworks.empty?
    lines << "  s.libraries = #{libraries.inspect}" unless libraries.empty?
    lines << "  s.dependency 'uniapp/UTS'"
    dependencies.each { |dependency| lines << "  #{dependency}" }
    lines << 'end'
    File.write(File.join(pod_path, "#{pod_name}.podspec"), "#{lines.join("\n")}\n")
  end

  def resource_lines(pod_path)
    resources_dir = File.join(pod_path, 'Resources')
    config_json = File.exist?(File.join(pod_path, 'config.json')) ? "'config.json'" : nil
    privacy = File.exist?(File.join(pod_path, 'PrivacyInfo.xcprivacy')) ? "'PrivacyInfo.xcprivacy'" : nil

    unless Dir.exist?(resources_dir)
      extras = [config_json, privacy].compact
      return ["  s.resources = [#{extras.join(', ')}]"] if extras.any?

      return []
    end

    children = Dir.children(resources_dir)
    bundles = children.select { |c| File.extname(c) == '.bundle' }
    non_bundles = children - bundles

    entries = []
    entries << "'Resources/**/*'" unless non_bundles.empty?
    bundles.each { |b| entries << "'Resources/#{b}'" }
    entries << config_json if config_json
    entries << privacy if privacy
    ["  s.resources = [#{entries.compact.join(', ')}]"]
  end

  def array_config(config, key)
    value = config[key]
    case value
    when Array then value.compact.map(&:to_s).reject(&:empty?)
    when String then value.empty? ? [] : [value]
    else []
    end
  end

  def normalize_dependencies(value)
    case value
    when Array
      value.filter_map { |item| dependency_line(item) }
    when Hash
      value.filter_map { |name, version| dependency_line({ 'name' => name, 'version' => version }) }
    else
      []
    end
  end

  def dependency_line(item)
    case item
    when String
      "s.dependency '#{item}'"
    when Hash
      name = item['name'] || item[:name] || item['pod'] || item[:pod]
      version = item['version'] || item[:version]
      subspecs = item['subspecs'] || item[:subspecs]
      return nil unless present?(name)

      line = "s.dependency '#{name}'"
      line += ", '#{version}'" if present?(version)
      return subspecs.map { |subspec| "s.dependency '#{name}/#{subspec}'#{", '#{version}'" if present?(version)}" }.join("\n  ") if subspecs.is_a?(Array) && !subspecs.empty?

      line
    end
  end

  def present?(value)
    !(value.nil? || (value.respond_to?(:empty?) && value.empty?))
  end
end
