DELETE FROM xdruple.xd_site;
INSERT INTO xdruple.xd_site(xd_site_name, xd_site_url, xd_site_notes) SELECT 'xTupleCommerce','http://flywheel.xd','ecomm site' WHERE NOT EXISTS (SELECT 1 FROM xdruple.xd_site WHERE xd_site_name = 'xTupleCommerce' AND xd_site_url='http://flywheel.xd' AND xd_site_notes='ecomm site');
