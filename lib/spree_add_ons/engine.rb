module SpreeAddOns
  class Engine < Rails::Engine
    require 'spree/core'
    isolate_namespace Spree
    engine_name 'spree_add_ons'

    # use rspec for tests
    config.generators do |g|
      g.test_framework :rspec
    end

    initializer "spree.add_on.environment" do |app|
      app.config.spree.calculators.add_class('add_ons')
      app.config.spree.calculators.add_ons << Spree::Calculator::FlatRate
    end

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), '../../app/**/*_decorator*.rb')) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end

      # force load for development
      if Rails.env.development?
        Dir.glob(File.join(File.dirname(__FILE__), '../../app/models/spree/add_on/*.rb')) do |c|
          Rails.configuration.cache_classes ? require(c) : load(c)
        end
      end

      if Rails.env.test?
        Dir.glob(File.join(File.dirname(__FILE__), './overrides/**/*_decorator*.rb')) do |c|
          Rails.configuration.cache_classes ? require(c) : load(c)
        end

        Dir.glob("#{File.join(File.dirname(__FILE__), './templates/**/*.rb')}") do |c|
          Rails.configuration.cache_classes ? require(c) : load(c)
        end

        if Spree::LineItem.table_exists?
          Spree::LineItem.register_price_modifier_hook(:add_on_total)
        end

        if Spree::Adjustment.table_exists?
          Spree::ItemAdjustments.register_item_adjustment_hook(:update_add_on_adjustments)
        end
      end

      if Spree::Order.table_exists?
        Spree::Order.register_line_item_comparison_hook(:add_on_matcher)
        Spree::Order.register_update_hook(:persist_add_on_totals)
      end
    end

    config.to_prepare &method(:activate).to_proc
  end
end
