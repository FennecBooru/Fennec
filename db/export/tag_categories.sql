SELECT tag_categories.id,
       tag_categories.name,
       tag_categories.aliases,
       tag_categories.header,
       tag_categories.display,
       tag_categories.color,
       tag_categories.color_alt,
       tag_categories.position,
       tag_categories.min_level,
       tag_categories.is_default,
       tag_categories.tag_count,
       tag_categories.created_at,
       tag_categories.updated_at
FROM public.tag_categories ORDER BY tag_categories.position ASC, tag_categories.id ASC
