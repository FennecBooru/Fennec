# frozen_string_literal: true

# Every link on the site map (/static/site_map), grouped into sections in display order
module SiteMap
  Section = Struct.new(:title, :links)
  Link = Struct.new(:label, :path_block, :policy, :action, :visible) do
    def path(user)
      Paths.new.instance_exec(user, &path_block)
    end

    def visible?(user)
      return false if visible && !visible.call(user)
      return true if policy.nil?
      Pundit.policy!(user, policy).public_send(action)
    end
  end

  @sections = []

  class << self
    attr_reader(:sections)
  end

  # what the path blocks are run in
  class Paths
    include(Rails.application.routes.url_helpers)
  end

  def self.section(title, &)
    @sections << Section.new(title, [])
    instance_eval(&)
  end

  # the block returns the path and is given the user, policy: is checked with action:, visible: is a lambda taking the user
  def self.link(label, policy: nil, action: :index?, visible: nil, &path)
    @sections.last.links << Link.new(label, path, policy, action, visible)
  end

  # [{ title:, links: [{ label:, path: }] }], without empty sections
  def self.sections_for(user)
    @sections.filter_map do |section|
      links = section.links.select { |link| link.visible?(user) }.map { |link| { label: link.label, path: link.path(user) } }
      { title: section.title, links: links } if links.any?
    end
  end

  logged_in = ->(user) { !user.is_anonymous? }
  logged_out = ->(user) { user.is_anonymous? }
  forums = ->(_) { AdminConfig.enable_forums? }
  pools = ->(_) { AdminConfig.enable_pools? }

  section("Posts") do
    link("Listing")                                                               { posts_path }
    link("Advanced Search", policy: Post, action: :search?)                       { search_posts_path }
    link("Upload", policy: Upload, action: :create?)                              { new_upload_path }
    link("Random", policy: Post, action: :random?)                                { random_posts_path }
    link("Favorites", policy: Favorite)                                           { favorites_path }
    link("Recommendations", visible: ->(_)                                        { Recommender.enabled? }) { post_recommendations_path }
    link("Similar Images Search", visible: ->(_)                                  { ErisProxy.enabled? }) { posts_eris_path }
    link("Deleted Index")                                                         { deleted_posts_path }
    link("Audio Tracks", policy: AudioTrack)                                      { post_audio_tracks_path }
    link("Uploaders", policy: Post, action: :uploaders?)                          { uploaders_posts_path }
    link("Upload Listing", policy: Upload)                                        { uploads_path }
    link("Disapprovals", policy: PostDisapproval, visible: ->(_)                  { AdminConfig.enable_post_approvals? }) { post_disapprovals_path }
    link("Deletion Reasons", policy: PostDeletionReason)                          { post_deletion_reasons_path }
    link("Replacement Rejection Reasons", policy: PostReplacementRejectionReason) { post_replacement_rejection_reasons_path }
    link("Help")                                                                  { help_page_path(id: "posts") }
    link("Upload Help")                                                           { help_page_path(id: "uploading") }
  end

  section("Post Events") do
    link("Listing")                  { post_events_path }
    link("Tag Changes")              { post_versions_path }
    link("Approvals", visible: ->(_) { AdminConfig.enable_post_approvals? }) { post_approvals_path }
    link("Flags")                    { post_flags_path }
    link("Appeals")                  { post_appeals_path }
    link("Replacements")             { post_replacements_path }
  end

  section("Popular") do
    link("Uploads")                        { uploads_popular_index_path }
    link("Views", visible: ->(_)           { Reports.enabled? }) { views_popular_index_path }
    link("Followed Tags", visible: ->(_)   { AdminConfig.enable_tag_following? }) { followed_tags_popular_index_path }
    link("Searches", visible: ->(_)        { Reports.enabled? }) { searches_popular_index_path }
    link("Missed Searches", visible: ->(_) { Reports.enabled? }) { missed_searches_popular_index_path }
  end

  section("Tags") do
    link("Listing")                                                      { tags_path }
    link("Changes")                                                      { tag_versions_path }
    link("Followed", policy: Tag, action: :followed?)                    { followed_tags_path }
    link("Categories")                                                   { tag_categories_path }
    link("MetaSearch", policy: Tag, action: :meta_search?)               { meta_search_tags_path }
    link("Aliases")                                                      { tag_aliases_path }
    link("Alias History")                                                { mod_actions_path(search: { action: "tag_alias_create,tag_alias_update" }) }
    link("Implications")                                                 { tag_implications_path }
    link("Implication History")                                          { mod_actions_path(search: { action: "tag_implication_create,tag_implication_update" }) }
    link("Bulk Update Requests")                                         { bulk_update_requests_path }
    link("Bulk Update Request History")                                  { bulk_update_request_versions_path }
    link("Bulk Update Request Imports", policy: BulkUpdateRequestImport) { bulk_update_request_imports_path }
    link("Cheat Sheet")                                                  { help_page_path(id: "cheatsheet") }
    link("Tagging Checklist")                                            { help_page_path(id: "tagging_checklist") }
    link("Help")                                                         { help_page_path(id: "tags") }
  end

  section("Artists") do
    link("Listing")                              { artists_path }
    link("URLs")                                 { artist_urls_path }
    link("Changes")                              { artist_versions_path }
    link("Avoid Posting Entries", visible: ->(_) { AdminConfig.enable_avoid_posting? }) { avoid_postings_path }
    link("Avoid Posting Changes", visible: ->(_) { AdminConfig.enable_avoid_posting? }) { avoid_posting_versions_path }
    link("Avoid Posting List", visible: ->(_)    { AdminConfig.enable_avoid_posting? }) { avoid_posting_static_path }
    link("Help")                                 { help_page_path(id: "artists") }
  end

  section("Characters") do
    link("Listing") { characters_path }
    link("URLs")    { character_urls_path }
    link("Changes") { character_versions_path }
  end

  section("Pools") do
    link("Gallery", visible: pools) { gallery_pools_path }
    link("Listing", visible: pools) { pools_path }
    link("Changes", visible: pools) { pool_versions_path }
    link("Help", visible: pools)    { help_page_path(id: "pools") }
  end

  section("Sets") do
    link("Listing")                                       { post_sets_path }
    link("Changes")                                       { post_set_versions_path }
    link("Maintainer Invites", policy: PostSetMaintainer) { post_set_maintainers_path }
    link("Help")                                          { help_page_path(id: "sets") }
  end

  section("Notes") do
    link("Listing") { notes_path }
    link("Search")  { search_notes_path }
    link("Changes") { note_versions_path }
    link("Help")    { help_page_path(id: "notes") }
  end

  section("Comments") do
    link("Listing") { comments_path }
    link("Search")  { search_comments_path }
    link("Help")    { help_page_path(id: "commenting") }
  end

  section("Forum") do
    link("Listing", visible: forums)                                             { forums_path }
    link("Topics", visible: forums)                                              { forum_topics_path }
    link("Posts", visible: forums)                                               { forum_posts_path }
    link("Search", visible: forums)                                              { search_forums_path }
    link("Categories", policy: ForumCategory, action: :create?, visible: forums) { forum_categories_path }
    link("Help", visible: forums)                                                { help_page_path(id: "forums") }
  end

  section("Wiki") do
    link("Listing") { wiki_pages_path }
    link("Search")  { search_wiki_pages_path }
    link("Changes") { wiki_page_versions_path }
    link("Help")    { help_page_path(id: "wiki") }
  end

  section("Users") do
    link("Listing")                             { users_path }
    link("Search")                              { search_users_path }
    link("Bans")                                { bans_path }
    link("Feedback", visible: ->(_)             { AdminConfig.enable_user_feedback? }) { user_feedbacks_path }
    link("Sign Up", visible: logged_out)        { new_user_path }
    link("Sign In", visible: logged_out)        { new_session_path }
    link("Reset Password", visible: logged_out) { new_users_password_reset_path }
    link("Login Reminder", visible: logged_out) { new_users_login_reminder_path }
    link("Help")                                { help_page_path(id: "accounts") }
  end

  section("Account") do
    link("Home", visible: logged_in)                           { home_users_path }
    link("Profile", visible: logged_in)                        { |user| user_path(user) }
    link("Settings", visible: logged_in)                       { edit_users_path }
    link("Messages", policy: Dmail)                            { dmails_path }
    link("Notifications", policy: Notification)                { notifications_path }
    link("Followed Tags", policy: Tag, action: :followed?)     { followed_tags_path }
    link("Events", policy: UserEvent)                          { user_events_path }
    link("Upload Limit", policy: User, action: :upload_limit?) { upload_limit_users_path }
    link("Blocked Users", visible: logged_in)                  { |user| user_blocks_path(user) }
    link("API Keys", policy: ApiKey)                           { |user| user_api_keys_path(user) }
    link("Passkeys", visible: logged_in)                       { user_passkeys_path }
    link("DMail Filter", visible: logged_in)                   { users_dmail_filter_path }
    link("Email Notifications", visible: logged_in)            { users_email_notification_path }
    link("Change Email", visible: logged_in)                   { new_users_email_change_path }
    link("Name Change Request", visible: logged_in)            { new_user_name_change_request_path }
    link("Refresh Counts", visible: logged_in)                 { new_users_count_fixes_path }
  end

  section("Site") do
    link("Rules", visible: ->(_)      { AdminConfig.enable_rules? }) { rules_path }
    link("Terms of Service")          { terms_of_service_path }
    link("Privacy Policy")            { privacy_policy_path }
    link("Contact")                   { contact_path }
    link("Staff")                     { staff_path }
    link("Takedowns", visible: ->(_)  { AdminConfig.enable_takedowns? }) { takedown_static_path }
    link("Discord", visible: ->(user) { AdminConfig.enable_discord? && user.can_discord? }) { discord_get_path }
    link("Themes")                    { theme_path }
    link("Keyboard Shortcuts")        { keyboard_shortcuts_path }
    link("Help Index")                { help_pages_path }
  end

  section("Tools") do
    link("News Updates")              { news_updates_path }
    link("Mascots")                   { mascots_path }
    link("Domain Icons")              { domain_icons_path }
    link("DText Links")               { dtext_links_path }
    link("Stats")                     { stats_path }
    link("Status")                    { status_path }
    link("DB Exports", visible: ->(_) { AdminConfig.db_exports_enabled? }) { db_exports_path }
    link("API Documentation")         { api_documentation_path }
    link("API Help")                  { help_page_path(id: "api") }
    link("Source Code")               { GayFurCity.config.source_code_url }
  end

  section("Moderation") do
    link("Mod Dashboard", policy: :moderator_dashboard, action: :show?)           { moderator_dashboard_path }
    link("Tickets")                                                               { tickets_path }
    link("Mod Actions")                                                           { mod_actions_path }
    link("Takedowns", policy: Takedown)                                           { takedowns_path }
    link("Upload Whitelist")                                                      { upload_whitelists_path }
    link("User Approvals", policy: UserApproval)                                  { moderator_user_approvals_path }
    link("Name Change Requests", policy: UserNameChangeRequest)                   { user_name_change_requests_path }
    link("User Text Versions", policy: UserTextVersion)                           { moderator_user_text_versions_path }
    link("Edit Histories", policy: EditHistory)                                   { edit_histories_path }
    link("Staff Notes", policy: StaffNote)                                        { staff_notes_path }
    link("Sessions", policy: UserSession)                                         { user_sessions_path }
    link("IP Addresses", policy: Moderator::IpAddrSearch)                         { moderator_ip_addrs_path }
    link("IP Bans", policy: IpBan)                                                { ip_bans_path }
    link("Email Blacklist", policy: EmailBlacklist)                               { email_blacklists_path }
    link("Alt List", policy: %i[admin user], action: :alt_list?)                  { alt_list_admin_users_path }
    link("Quick Rules", policy: QuickRule, action: :create?, visible: ->(_)       { AdminConfig.enable_rules? }) { quick_rules_path }
    link("Rule Categories", policy: RuleCategory, action: :order?, visible: ->(_) { AdminConfig.enable_rules? }) { order_rule_categories_path }
    link("Stuck DNP Tags", policy: :stuck_dnp, action: :create?)                  { new_admin_stuck_dnp_path }
    link("Post Reowner", policy: :reowner, action: :create?)                      { new_admin_reowner_path }
    link("Destroyed Posts", policy: DestroyedPost)                                { admin_destroyed_posts_path }
  end

  section("Media Assets") do
    link("Uploads", policy: UploadMediaAsset)                          { upload_media_assets_path }
    link("Replacements", policy: PostReplacementMediaAsset)            { post_replacement_media_assets_path }
    link("Audio Tracks", policy: AudioTrackMediaAsset)                 { audio_track_media_assets_path }
    link("Mascots", policy: MascotMediaAsset)                          { mascot_media_assets_path }
    link("Domain Icons", policy: DomainIconMediaAsset)                 { domain_icon_media_assets_path }
    link("Site Assets", policy: SiteMediaAsset)                        { site_media_assets_path }
    link("File Statuses", policy: MediaAsset, action: :show_statuses?) { media_asset_status_path }
  end

  section("Admin") do
    link("Admin Dashboard", policy: AdminDashboard, action: :show?) { admin_dashboard_path }
    link("Config", policy: AdminConfig, action: :show?)             { admin_config_path }
    link("Site Assets", policy: SiteAsset)                          { site_assets_path }
    link("Security", policy: %i[security dashboard])                { security_root_path }
    link("Audit Logs", policy: StaffAuditLog)                       { admin_audit_logs_path }
    link("Application Logs", policy: Admin::ApplicationLog)         { application_admin_logs_path }
    link("Request Logs", policy: Admin::RequestLog)                 { request_admin_logs_path }
    link("Performance Logs", policy: Admin::PerformanceLog)         { performance_admin_logs_path }
    link("Exceptions", policy: ExceptionLog)                        { admin_exceptions_path }
    link("System", policy: SystemInfo, action: :show?)              { system_path }
    link("Database Size", policy: SystemInfo, action: :dbsize?)     { dbsize_system_path }
  end
end
