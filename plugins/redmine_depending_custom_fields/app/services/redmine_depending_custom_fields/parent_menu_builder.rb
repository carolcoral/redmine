# app/services/redmine_depending_custom_fields/parent_menu_builder.rb
module RedmineDependingCustomFields
  class ParentMenuBuilder
    def self.build(issues = [])
      # select parent fields for the given issues
      parents  = ParentDetector.for_issues(issues)
      mapping  = Rails.cache.fetch('depending_custom_fields/mapping') { MappingBuilder.build }

      parents.map do |cf|
        {
          id:   cf.id,
          name: cf.name,
          # all possible child values for this parent field
          values: mapping
                    .select { |_, v| v[:parent_id].to_i == cf.id }
                    .values
                    .flat_map { |v| v[:map].keys }
                    .uniq
        }
      end
    end
  end
end
