SELECT tag_versions.id,
       tag_versions.created_at,
       tag_versions.updated_at,
       tag_versions.category_id,
       tag_versions.is_locked,
       tag_versions.is_deprecated,
       tag_versions.tag_id,
       tag_versions.updater_id,
       tag_versions.reason
FROM public.tag_versions ORDER BY tag_versions.id ASC
