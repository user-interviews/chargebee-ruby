module ChargeBee
  class ItemPrice < Model

    class Tier < Model
      attr_accessor :starting_unit, :ending_unit, :price, :starting_unit_in_decimal, :ending_unit_in_decimal, :price_in_decimal
    end

    class TaxDetail < Model
      attr_accessor :tax_profile_id, :avalara_sale_type, :avalara_transaction_type, :avalara_service_type, :avalara_tax_code, :taxjar_product_code
    end

    class AccountingDetail < Model
      attr_accessor :sku, :accounting_code, :accounting_category1, :accounting_category2
    end

  attr_accessor :id, :name, :item_family_id, :item_id, :description, :status, :external_name,
  :pricing_model, :price, :period, :currency_code, :period_unit, :trial_period, :trial_period_unit,
  :shipping_period, :shipping_period_unit, :billing_cycles, :free_quantity, :free_quantity_in_decimal,
  :price_in_decimal, :resource_version, :updated_at, :created_at, :invoice_notes, :tiers, :is_taxable,
  :tax_detail, :accounting_detail, :metadata, :item_type, :archivable, :parent_item_id

  # OPERATIONS
  #-----------

  def self.create(params, env=nil, headers={})
    Request.send('post', uri_path("item_prices"), params, env, headers)
  end

  def self.retrieve(id, env=nil, headers={})
    Request.send('get', uri_path("item_prices",id.to_s), {}, env, headers)
  end

  def self.update(id, params={}, env=nil, headers={})
    Request.send('post', uri_path("item_prices",id.to_s), params, env, headers)
  end

  def self.list(params={}, env=nil, headers={})
    Request.send_list_request('get', uri_path("item_prices"), params, env, headers)
  end

  def self.delete(id, env=nil, headers={})
    Request.send('post', uri_path("item_prices",id.to_s,"delete"), {}, env, headers)
  end

  end # ~ItemPrice
end # ~ChargeBee