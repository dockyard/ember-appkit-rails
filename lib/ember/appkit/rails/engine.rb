class Ember::Appkit::Rails::Engine < ::Rails::Engine
  config.ember = ActiveSupport::OrderedOptions.new
  config.ember.paths = ActiveSupport::OrderedOptions.new
  config.ember.namespaces = ActiveSupport::OrderedOptions.new
  config.ember.prefix_patterns = ActiveSupport::OrderedOptions.new

  config.ember.paths.app = 'app'
  config.ember.paths.config = 'config'
  config.ember.namespaces.app = 'app'
  config.ember.namespaces.config = 'config'

  config.ember.enable_logging = ::Rails.env.development?

  initializer :appkit_transpiler do
    config.ember.prefix_patterns.app ||= Regexp.new(File.join(::Rails.root, config.ember.namespaces.app))
    config.ember.prefix_patterns.config ||= Regexp.new(File.join(::Rails.root, config.ember.namespaces.config))

    ES6ModuleTranspiler.add_prefix_pattern config.ember.prefix_patterns.app, config.ember.namespaces.app
    ES6ModuleTranspiler.add_prefix_pattern config.ember.prefix_patterns.config, config.ember.namespaces.config
    ES6ModuleTranspiler.transform = lambda { |name| name.split('/').map { |n| n.underscore.dasherize }.join('/') }
  end

  initializer :appkit_handlebars do
    config.handlebars = ActiveSupport::OrderedOptions.new

    config.handlebars.precompile = true
    config.handlebars.templates_root = "templates"
    config.handlebars.templates_path_separator = '/'
    config.handlebars.output_type = :global

    config.before_initialize do |app|
      Sprockets::Engines # force autoloading
      Sprockets.register_engine '.handlebars', Ember::Appkit::Rails::Template
      Sprockets.register_engine '.hbs', Ember::Appkit::Rails::Template
      Sprockets.register_engine '.hjs', Ember::Appkit::Rails::Template
    end

    config.handlebars ||= ActiveSupport::OrderedOptions.new
    config.handlebars.output_type   = :amd
    config.handlebars.amd_namespace = config.ember.namespaces.app
  end

  initializer :appkit_remove_generators do
    ::Rails.configuration.generators do |generate|
      generate.helper false
      generate.assets false
      generate.template_engine false
    end
  end

  initializer :appkit_router do |app|
    app.routes.append do
      get '/' => "landing#index"
    end
  end

  initializer :appkit_sprockets do
    assets = Sprockets::Railtie.config.assets

    assets_javascript = assets.paths.delete(::Rails.root.join('app','assets','javascripts').to_s)

    index_of_last_app_assets = assets.paths.rindex{|s| s.start_with?(::Rails.root.join('app').to_s) } + 1
    assets.paths.insert(index_of_last_app_assets, assets_javascript) if assets_javascript
    assets.paths.insert(index_of_last_app_assets, File.join(::Rails.root, config.ember.paths.config))
    assets.paths.insert(index_of_last_app_assets, File.join(::Rails.root, config.ember.paths.app))
  end

  initializer :appkit_setup_vendor, :group => :all do |app|
    # Allow a local variant override
    override_path = app.root.join("vendor/assets/ember/")
    app.assets.append_path(override_path.to_s) if override_path.exist?

    app.assets.append_path(File.dirname(::Ember::Source.bundled_path_for("ember.js")))
    app.assets.append_path(File.dirname(::Ember::Data::Source.bundled_path_for("ember-data.js")))
    app.assets.append_path(File.expand_path('../', ::Handlebars::Source.bundled_path))
  end
end
