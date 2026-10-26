# frozen_string_literal: true

require("test_helper")

module Rules
  class QuickControllerTest < ActionDispatch::IntegrationTest
    context("The quick rules controller") do
      setup do
        @quick_rule = create(:quick_rule)
      end

      context("new action") do
        context("access control") do
          asserts do
            access.none.api_key.get(new_quick_rule_path)
          end
        end
      end

      context("edit action") do
        context("access control") do
          asserts do
            access.none.api_key.get { edit_quick_rule_path(@quick_rule) }
          end
        end
      end

      context("create action") do
        context("access control") do
          asserts do
            access.none.api_key.post(quick_rules_path).params { { quick_rule: { reason: SecureRandom.hex(6), rule_id: @quick_rule.rule_id } } }
          end
        end
      end

      context("update action") do
        context("access control") do
          asserts do
            access.none.api_key.put { quick_rule_path(@quick_rule) }.params { { quick_rule: { reason: SecureRandom.hex(6) } } }
          end
        end
      end

      context("destroy action") do
        context("access control") do
          asserts do
            access.none.api_key.delete { quick_rule_path(@quick_rule) }
          end
        end
      end

      context("order action") do
        context("access control") do
          asserts do
            access.none.api_key.get(order_quick_rules_path)
          end
        end
      end

      context("reorder action") do
        context("access control") do
          asserts do
            access.none.api_key.json.post(reorder_quick_rules_path)
          end
        end
      end
    end
  end
end
