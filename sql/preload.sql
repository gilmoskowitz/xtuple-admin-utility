UPDATE xt.ext SET ext_location='/xdruple-extension'
WHERE ext_name='xdruple' AND  EXISTS (
  SELECT 1 FROM xt.ext WHERE ext_name='xdruple' AND ext_location='/private-extensions'
);


INSERT INTO xt.ext (ext_name,  ext_descrip,  ext_location,  ext_load_order)
SELECT
'nodejsshim', 'xTuple ERP Node.js shims for the Qt Script Engine.', '/nodejsshim', 10
WHERE NOT EXISTS (
  SELECT 1 FROM xt.ext WHERE ext_name = 'nodejsshim'
);


INSERT INTO xt.ext (ext_name,  ext_descrip,  ext_location,  ext_load_order)
SELECT
'enhancedpricing', 'xTuple ERP Enhanced Pricing extension', '/enhanced-pricing', 130
WHERE NOT EXISTS (
  SELECT 1 FROM xt.ext WHERE ext_name = 'enhancedpricing'
);

INSERT INTO xt.ext (ext_name,  ext_descrip,  ext_location,  ext_load_order)
SELECT
'paymentgateways', 'xTuple Payment Gateways', '/payment-gateways', 150
WHERE NOT EXISTS (
  SELECT 1 FROM xt.ext WHERE ext_name = 'paymentgateways'
);


INSERT INTO xt.ext (ext_name,  ext_descrip,  ext_location,  ext_load_order)
SELECT
'xdruple', 'xDruple Extension', '/xdruple-extension', 150
WHERE NOT EXISTS (
  SELECT 1 FROM xt.ext WHERE ext_name = 'xdruple'
);
