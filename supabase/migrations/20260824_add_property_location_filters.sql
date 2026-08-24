-- ============================================================
-- JUMAA - PROPERTY LOCATION FILTERS
-- Add county + subcounty to properties
-- ============================================================

alter table properties
add column if not exists county text not null default '';

alter table properties
add column if not exists subcounty text not null default '';

-- Keep location as the specific area/neighborhood.
comment on column properties.county is
'Kenyan county containing the property';

comment on column properties.subcounty is
'Kenyan subcounty containing the property';

comment on column properties.location is
'Specific area/neighborhood within the subcounty';
