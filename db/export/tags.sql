SELECT tags.id,
       tags.name,
       tags.post_count,
       tags.category_id,
       tags.related_tags,
       tags.related_tags_updated_at,
       tags.created_at,
       tags.updated_at,
       tags.is_locked
FROM public.tags ORDER BY tags.id ASC
