# frozen_string_literal: true

require 'active_support/concern'
require 'kaminari/activerecord'

module ActiveQueryable
	extend ActiveSupport::Concern

  QUERYABLE_VALID_PARAMS = [:filter, :sort, :page, :per].freeze

  included do
    class_attribute :_queryable_default_order
    class_attribute :_queryable_default_page
    class_attribute :_queryable_default_per
    class_attribute :_queryable_filter_keys
    class_attribute :_queryable_expandable_filter_keys
	end

	module Initializer
    def as_queryable
			send :include, ActiveQueryable
		end
	end

  module ClassMethods
    def queryable(options)
      self._queryable_default_order = options[:order] || { id: :asc }
      self._queryable_default_page = options[:page] || 1
      self._queryable_default_per = options[:per] || 25
      self._queryable_filter_keys = (((options[:filter] || [])).map(&:to_sym))

      scope :query_by, ->(params) { queryable_scope(params) }
      scope :of_not, ->(ids) { where.not(id: ids) }
    end

    def expand_queryable(options)
      self._queryable_expandable_filter_keys ||= []
      self._queryable_expandable_filter_keys += (((options[:filter] || [])).map(&:to_sym))
    end

    def queryable_scope(params)
      params = params.to_unsafe_h if params.respond_to? :to_unsafe_h
      params = params.with_indifferent_access if params.respond_to?(:with_indifferent_access)
      params.each_key { |k| QUERYABLE_VALID_PARAMS.include?(k.to_sym) || Rails.logger.error("Invalid key #{k} in queryable") }

      order_params = queryable_validate_order_params(params[:sort])
      query = queryable_parse_order_scope(order_params, self)

      queryable_filtered_scope(params, query)
    end

    private

    def queryable_filtered_scope(params, query)
      filter_params = queryable_validate_filter_params(params[:filter])

      page_params = queryable_validate_page_params(params)

      scope = queryable_parse_filter_scope(filter_params, query)

      unless page_params[:per] == 'all'
        scope = scope
                .page(page_params[:page])
                .per(page_params[:per])
      end

      scope
    end

    def queryable_validate_order_params(params)
      queryable_parse_order_params(params) || _queryable_default_order
    end

    def queryable_validate_page_params(params)
      page_params = {}
      if params[:page].respond_to?(:dig)
        page_params[:page] = params.dig(:page, :number) || _queryable_default_page
        page_params[:per] = params.dig(:page, :size) || params[:per] || _queryable_default_per
      else
        page_params[:page] = params[:page] || _queryable_default_page
        page_params[:per] = params[:per] || _queryable_default_per
      end
      page_params
    end

    def queryable_validate_filter_params(filter_params)
      return nil if filter_params.nil?

      filters = (((self._queryable_filter_keys || []) | (self._queryable_expandable_filter_keys || [])) + ['not']).map(&:to_sym)
      unpermitted = filter_params.except(*filters)
      Rails.logger.warn("Unpermitted queryable parameters: #{unpermitted.keys.join(', ')}") if unpermitted.present?

      filter_params.slice(*filters)
    end

    def queryable_parse_order_params(params)
      return nil unless params.is_a? String

      params.split(',').map! do |param|
        clean_param = param.start_with?('-') ? param[1..-1] : param
        [clean_param, clean_param == param ? :asc : :desc]
      end.to_h
    end

    def queryable_parse_order_scope(params, query)
      return query unless params

      params.inject(query) do |current_query, (k, v)|
        scope = "by_#{k}"

        if current_query.respond_to?(scope, true)
          current_query.public_send(scope, v)
        else
          current_query.order(params)
        end
      end || query
    end

    def queryable_parse_filter_scope(params, query)
      return query unless params

      params.inject(query) do |current_query, (k, v)|
        scope = "of_#{k}"


        if current_query.respond_to?(scope, true)
          current_query.public_send(scope, v)
        else
          current_query.where(k => v)
        end
      end
    end
  end
end
ActiveRecord::Base.send :extend, ActiveQueryable::Initializer