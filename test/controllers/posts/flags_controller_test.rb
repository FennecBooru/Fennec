# frozen_string_literal: true

require("test_helper")

module Posts
  class FlagsControllerTest < ActionDispatch::IntegrationTest
    context("The post flags controller") do
      setup do
        @user = create(:user, created_at: 2.weeks.ago)
        @post = create(:post, uploader: @user)
        @post_flag = create(:post_flag, post: @post, creator: @user)
      end

      context("new action") do
        should("render") do
          get_auth(new_post_flag_path, @user, params: { post_flag: { post_id: @post.id } })

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MEMBER).get(new_post_flag_path).params { { post_flag: { post_id: @post.id } } }
          end
        end
      end

      context("index action") do
        should("render") do
          get_auth(post_flags_path, @user)

          assert_response(:success)
        end

        context("with search parameters") do
          should("render") do
            get_auth(post_flags_path, @user, params: { search: { post_id: @post_flag.post_id } })

            assert_response(:success)
          end
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ANONYMOUS).get(post_flags_path)
            access.gte(User::Levels::ANONYMOUS).json.get(post_flags_path)
          end
        end

        context("search parameters") do
          subject { post_flags_path }
          setup do
            PostFlag.delete_all
            @creator = create(:user)
            @janitor = create(:janitor_user)
            @admin = create(:admin_user)
            @post = create(:post, tag_string: "foo")
            @post_flag = create(:post_flag, post: @post, creator: @creator, creator_ip_addr: "127.0.0.2", is_deletion: false, reason_name: "uploading_guidelines", note: "bar", is_resolved: true)
          end

          asserts do
            search(:reason_matches, "uploading_guidelines").records { [@post_flag] }
            search(:note_matches, "bar").records { [@post_flag] }.user { @janitor }
            search(:is_resolved, "true").records { [@post_flag] }
            search(:post_id).value { @post.id }.records { [@post_flag] }
            search(:post_tags_match, "foo").records { [@post_flag] }
            search(:type, "flag").records { [@post_flag] }
            search(:creator_id).value { @creator.id }.records { [@post_flag] }.user { @creator }
            search(:creator_name).value { @creator.name }.records { [@post_flag] }.user { @creator }
            search(:ip_addr, "127.0.0.2").records { [@post_flag] }.user { @admin }
            search.shared.records { [@post_flag] }
          end
        end
      end

      context("create action") do
        should("create a new flag") do
          post = create(:post)
          assert_difference("PostFlag.count", 1) do
            post_auth(post_flags_path, @user, params: { format: :json, post_flag: { post_id: post.id, reason_name: "dnp_artist" } })
          end
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MEMBER).post(post_flags_path).params { { post_flag: { post_id: create(:post).id, reason_name: "dnp_artist" } } }.success(:redirect)
            access.gte(User::Levels::MEMBER).json.post(post_flags_path).params { { post_flag: { post_id: create(:post).id, reason_name: "dnp_artist" } } }
          end
        end
      end

      context("when flags are disabled") do
        setup do
          stub_admin_config(:enable_post_flags, false)
          @other = create(:post)
          @approver = create(:janitor_user)
        end

        should("not allow flagging") do
          get_auth(new_post_flag_path, @user, params: { post_flag: { post_id: @other.id } })

          assert_response(:not_implemented)

          assert_no_difference("PostFlag.count") do
            post_auth(post_flags_path, @user, params: { post_flag: { post_id: @other.id, reason_name: "uploading_guidelines" }, format: :json })
          end
          assert_response(:not_implemented)

          get_auth(post_path(@other), @user)

          assert_select("#flag", count: 0)
        end

        should("still allow handling existing flags and deleting posts") do
          get_auth(post_flags_path, @user)

          assert_response(:success)

          delete_auth(post_flag_path(@post), @approver, params: { format: :json })

          assert_response(:success)
          assert_not(@post.reload.is_flagged?)

          @other.delete!(@approver, "test")

          assert_predicate(@other.reload, :is_deleted?)
        end
      end
    end
  end
end
