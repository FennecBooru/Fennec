# frozen_string_literal: true

require("test_helper")

class SiteMapTest < ActiveSupport::TestCase
  def labels_for(user)
    SiteMap.sections_for(user).to_h { |section| [section[:title], section[:links].pluck(:label)] }
  end

  context("SiteMap") do
    should("resolve every link") do
      user = create(:owner_user)

      SiteMap.sections.each do |section|
        section.links.each do |link|
          assert_predicate(link.path(user), :present?, "#{section.title} #{link.label}")
        end
      end
    end

    should("hide links the user can't see") do
      labels = labels_for(User.anonymous)

      assert_includes(labels["Users"], "Sign Up")
      assert_nil(labels["Account"])
      assert_not_includes(labels["Posts"], "Disapprovals")
      assert_nil(labels["Admin"])
    end

    should("show staff links to staff") do
      user = create(:owner_user)
      labels = labels_for(user)

      assert_not_includes(labels["Users"], "Sign Up")
      assert_includes(labels["Account"], "Profile")
      assert_includes(labels["Admin"], "Admin Dashboard")
      assert_includes(SiteMap.sections_for(user).find { |s| s[:title] == "Account" }[:links], { label: "Profile", path: "/users/#{user.id}" })
    end

    should("drop empty sections") do
      section = SiteMap::Section.new("Empty", [SiteMap::Link.new("Hidden", proc { posts_path }, nil, :index?, ->(_) { false })])
      SiteMap.sections << section

      assert_not_includes(labels_for(User.anonymous).keys, "Empty")
    ensure
      SiteMap.sections.delete(section)
    end
  end
end
