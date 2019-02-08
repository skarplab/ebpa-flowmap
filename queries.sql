-- Combine tables into format useful for generating origin-to-destination lines for parks and census blocks
WITH etj_centroids as (
	SELECT rpcb.geoid10, st_x(st_transform(geom, 4326)) as cb_x, st_y(st_transform(geom, 4326)) as cb_y, geom
	FROM ebpa.raleigh_plus_censusblockcentroids_2010 as rpcb
	JOIN ebpa.raleigh_etj_censusblocks_bg_2010_geoid10 as e
    ON rpcb.geoid10 = e.block_geoid10
),
los_parks as (
	SELECT rp.parkid, rp.name, st_x(st_transform(st_pointonsurface(rp.geom), 4326)) as p_x, st_y(st_transform(st_pointonsurface(rp.geom), 4326)) as p_y, rp.geom as geom
	FROM ebpa.parks_los_current as rp
	UNION ALL
	SELECT sc.parkid, sc.name, st_x(st_transform(st_pointonsurface(sc.geom), 4326)) as p_x, st_y(st_transform(st_pointonsurface(sc.geom), 4326)) as p_y, sc.geom as geom
	FROM ebpa.raleigh_county_state_parks as sc																					   
)

SELECT r.geoid as origin_id, cb_x as origin_x, cb_y as origin_y,
	   p.parkid, r.park as destination_id, p_x as destination_x, p_y as destination_y,
	   analysis_class, total_length
FROM scratch.ebpa_routes_all as r
JOIN los_parks as p
ON r.park = p.name
JOIN etj_centroids as e
ON r.geoid = e.geoid10;


-- Combined LOS COR parks and state/county parks
SELECT rp.parkid, rp.name, st_x(st_transform(st_pointonsurface(rp.geom), 4326)) as p_x, st_y(st_transform(st_pointonsurface(rp.geom), 4326)) as p_y, rp.geom as geom
	FROM ebpa.parks_los_current as rp
	UNION ALL
	SELECT sc.parkid, sc.name, st_x(st_transform(st_pointonsurface(sc.geom), 4326)) as p_x, st_y(st_transform(st_pointonsurface(sc.geom), 4326)) as p_y, sc.geom as geom
	FROM ebpa.raleigh_county_state_parks as sc


-- Combine all the runs into one table
CREATE MATERIALIZED VIEW scratch.ebpa_routes_all AS
SELECT name, park, geoid, total_length, 'Half' as analysis_class, geom FROM scratch.ebpa_routes_halfmi
UNION ALL
SELECT name, park, geoid, total_length, '1' as analysis_class, geom FROM scratch.ebpa_routes_1mi
UNION ALL
SELECT name, park, geoid, total_length, '2' as analysis_class, geom FROM scratch.ebpa_routes_2mi
UNION ALL
SELECT name, park, geoid, total_length, '4' as analysis_class, geom FROM scratch.ebpa_routes_4mi

-- Create an ebpa dataset with scores and 2018 population density calculated
select los.geoid10,
	   los.los_dist_score,
	   los.los_acre_score,
	   los.los_exp_score,
	   los.los_total_score,
	   los.la_dist_score,
	   los.la_acre_score,
	   los.la_exp_score,
	   los.la_total_score,
	   los.gw_score_loop_contiguous,
	   los.los_gw_total_score,
	   los.la_gw_total_score,
	   pop.totpop,
	   st_area(cb.geom) / 27878400 as area,
	   pop.totpop/(st_area(cb.geom) / 27878400) as popdensity_sqmi,
	   st_transform(cb.geom, 4326) as geom
from ebpa.combined_statecounty_gw_analysis los
join demographics.population pop
on los.geoid10 = pop.geoid10
join ebpa.raleigh_plus_censusblocks_no_attr_2010 cb
on los.geoid10 = cb.geoid10