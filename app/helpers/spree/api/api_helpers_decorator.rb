Spree::Api::ApiHelpers.module_eval do
  mattr_reader :add_on_attributes
  class_variable_set(:@@add_on_attributes, [:id, :master_id, :images, :is_master, :type, :name, :values])

  class_variable_set(:@@line_item_attributes, class_variable_get(:@@line_item_attributes).push(:add_ons))
  class_variable_set(:@@line_item_attributes, class_variable_get(:@@line_item_attributes).push(:available_add_ons))
  class_variable_set(:@@product_attributes, class_variable_get(:@@product_attributes).push(:add_ons))
end