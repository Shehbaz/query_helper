module PatternQueryHelper
  class Filter

    attr_accessor :operator, :criterion, :comparate, :operator_code, :aggregate, :bind_variable, :cte_filter

    def initialize(
      operator_code:,
      criterion:,
      comparate:,
      aggregate: false,
      cte_filter: true # Filter after creating a common table expression with the rest of the query.  This will happen if the filter map doesn't include the comparate requested.
    )
      @operator_code = operator_code
      @criterion = criterion # Converts to a string to be inserted into sql.
      @comparate = comparate
      @aggregate = aggregate
      @bind_variable = SecureRandom.hex.to_sym

      translate_operator_code()
      mofify_criterion()
      modify_comparate()
      validate_criterion()
    end

    def sql_string
      case operator_code
      when "in", "notin"
        "#{comparate} #{operator} (:#{bind_variable})"
      when "null"
        "#{comparate} #{operator}"
      else
        "#{comparate} #{operator} :#{bind_variable}"
      end

    end

    private

    def translate_operator_code
      @operator = case operator_code
        when "gte"
          ">="
        when "lte"
          "<="
        when "gt"
          ">"
        when "lt"
          "<"
        when "eql"
          "="
        when "noteql"
          "!="
        when "in"
          "in"
        when "like"
          "like"
        when "notin"
          "not in"
        when "null"
          if criterion.to_s == "true"
            "is null"
          else
            "is not null"
          end
        else
          raise ArgumentError.new("Invalid operator code: '#{operator_code}'")
      end
    end

    def mofify_criterion
      # lowercase strings for comparison
      @criterion.downcase! if criterion.class == String && criterion.scan(/[a-zA-Z]/).any?

      # turn the criterion into an array for in and notin comparisons
      @criterion = criterion.split(",") if ["in", "notin"].include?(operator_code) && criterion.class != Array
    end

    def modify_comparate
      # lowercase strings for comparison
      @comparate = "lower(#{@comparate})" if criterion.class == String && criterion.scan(/[a-zA-Z]/).any?
    end

    def validate_criterion
      case operator_code
        when "gte", "lte", "gt", "lt"
          begin
            Time.parse(criterion.to_s)
          rescue
            begin
              Date.parse(criterion.to_s)
            rescue
              begin
                Float(criterion.to_s)
              rescue
                invalid_criterion_error()
              end
            end
          end
        when "in", "notin"
          invalid_criterion_error() unless criterion.class == Array
        when "null"
          invalid_criterion_error() unless ["true", "false"].include?(criterion.to_s)
      end
      true
    end

    def invalid_criterion_error
      raise ArgumentError.new("'#{criterion}' is not a valid criterion for the '#{operator}' operator")
    end
  end
end