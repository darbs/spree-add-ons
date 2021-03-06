module Spree
  LineItem.class_eval do
    validate :ensure_valid_add_ons

    after_save :attach_add_ons
    after_save :persist_add_on_total

    attr_accessor :add_ons_to_add
    attr_accessor :add_on_props

    has_many :add_ons, through: :adjustments, source: :source

    def add_ons
      # Come on rails get your shit together
      # Cannot unscope default for soft deletes
      # https://github.com/rails/rails/issues/10643
      # if we remove a subclass file...
      klasses = Spree::AddOn.subclasses.push(Spree::AddOn).map{|klass| "'#{klass.to_s}'"}.join(",")
      Spree::AddOn.unscoped.joins("INNER JOIN spree_adjustments ON spree_adjustments.source_id = spree_add_ons.id AND spree_adjustments.source_type IN (#{klasses})").where("source_id = spree_add_ons.id AND adjustable_id = ?", id)
    end

    # add_ons = [
    #   {
    #     id: 123,
    #     master_id: 1
    #     values: {}
    #   },
    #   ...
    # ]
    def add_ons=(*new_add_ons)
      setup_add_ons(new_add_ons)
      ensure_valid_add_ons
    end

    def available_add_ons
      product.add_ons.active
    end

    def display_add_on_total
      Spree::Money.new(add_on_total, {currency: currency})
    end

    private

    def setup_add_ons(*new_add_ons)
      @add_ons_to_add = []
      master = Spree::AddOn.master.find(new_add_ons.flatten!.map { |add| add[:master_id] })
      master.each do |master|
        add_hash = new_add_ons.select { |ao| ao[:master_id] == master.id }.first
        value = add_hash[:values] || {}
        @add_ons_to_add.push({
                                 master: master,
                                 values: value
                             })
      end

    end

    def attach_add_ons
      return if @add_ons_to_add.nil?

      if errors.any?
        raise ActiveRecord::Rollback
      end

      adjustments.add_ons.destroy_all

      @add_ons_to_add.each do |hash|
        hash[:master].attach_add_on(self, hash[:values])
      end

      # TODO find away so that this is called implicitly
      update_tax_charge
      recalculate_adjustments
      @add_ons_to_add = nil
    end

    def ensure_valid_add_ons
      current_add_ons = add_ons

      if add_ons_to_add.present?
        current_add_ons.concat(add_ons_to_add.map {|add_on| add_on[:master] })
      end

      invalid_add_ons = current_add_ons.map(&:master) - product.add_ons
      unless current_add_ons.empty? || invalid_add_ons.empty?
        invalid_message = invalid_add_ons.map { |add| add.name }.join(", ") + (invalid_add_ons.length > 1 ? " are" : " is")
        errors[:base] << "#{invalid_message} not a valid add on for #{product.name}"
      end
    end

    def persist_add_on_total
      update_columns(:add_on_total => add_on_total)
    end

  end
end