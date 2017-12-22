-- Make sure uom are present for weight and dimension
    INSERT INTO uom( uom_name, uom_descrip, uom_item_weight)
    SELECT 'EA', 'Each', False
    WHERE NOT EXISTS (SELECT 1 FROM uom WHERE uom_name = 'EA');

    INSERT INTO uom( uom_name, uom_descrip, uom_item_weight)
    SELECT 'LBS', 'Pounds', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM uom WHERE uom_name = 'LBS');

    INSERT INTO uom( uom_name, uom_descrip, uom_item_dimension)
    SELECT 'IN', 'Inches', TRUE
    WHERE NOT EXISTS (SELECT 1 FROM uom WHERE uom_name = 'IN');

-- Need this default info
         INSERT INTO shipchrg (shipchrg_name, shipchrg_descrip, shipchrg_custfreight)
         SELECT 'CHARGE', 'Xpress Default', TRUE
         WHERE NOT EXISTS (SELECT 1 FROM shipchrg WHERE shipchrg_name = 'CHARGE');

        INSERT INTO custtype (custtype_code, custtype_descrip) 
        SELECT  'CUSTOMER', 'Xpress Default'
        WHERE NOT EXISTS (SELECT 1 FROM custtype WHERE custtype_code = 'CUSTOMER');

        INSERT INTO api.salesrep (number, name, commission_percent)
        SELECT 'SALES', 'Xpress Default', 0
        WHERE NOT EXISTS (SELECT 1 FROM api.salesrep WHERE number = 'SALES');

        INSERT INTO shipvia (shipvia_code,shipvia_descrip)
          SELECT 'UPS','UPS Ship Via'
         WHERE NOT EXISTS (SELECT 1 FROM shipvia WHERE shipvia_code = 'UPS');

SELECT setmetric('DefaultShipFormId',(SELECT coalesce(shipform_id, '-1')::TEXT FROM shipform WHERE shipform_name= 'Xpress Sales Packing List' ));
SELECT setmetric('DefaultShipViaId',coalesce(getshipviaid( 'UPS'), '-1')::TEXT);
SELECT setmetric('DefaultCustType',  getcusttypeid('CUSTOMER')::text);
SELECT setmetric('DefaultShipChrgId',coalesce(getshipchrgid( 'CHARGE'), '-1')::TEXT);
SELECT setmetric('DefaultSalesRep',coalesce(getsalesrepid( 'SALES'), '-1')::TEXT);

-- add some default terms
    INSERT INTO terms (terms_code, terms_descrip, terms_type, terms_duedays, terms_discdays,
    terms_discprcnt, terms_cutoffday, terms_ap, terms_ar, terms_fincharg)
    SELECT 'PREPAID', 'Prepaid', 'D', 0, 0, 0, 0, TRUE, TRUE, FALSE
    WHERE NOT EXISTS (SELECT 1 FROM terms WHERE terms_code = 'PREPAID');

    INSERT INTO terms (terms_code, terms_descrip, terms_type, terms_duedays, terms_discdays,
    terms_discprcnt, terms_cutoffday, terms_ap, terms_ar, terms_fincharg)
    SELECT 'NET-30', 'Net 30', 'D', 30, 0, 0, 0, TRUE, TRUE, FALSE
    WHERE NOT EXISTS (SELECT 1 FROM terms WHERE terms_code = 'NET-30');

    SELECT setmetric('DefaultTerms', gettermsid('NET-30')::text);

    INSERT INTO taxzone (taxzone_code, taxzone_descrip)
    SELECT 'MAIN-TAXABLE','Main Taxable Zone'
     WHERE NOT EXISTS ( SELECT 1 FROM taxzone WHERE taxzone_code = 'MAIN-TAXABLE');

-- Add Default Guest Account for Web Portal
    INSERT INTO api.customer ( customer_number, customer_type, customer_name, active,
    default_tax_zone, default_terms, billing_contact_first, billing_contact_last, notes, allow_free_form_shipto, allow_free_form_shipto, preferred_selling_site)
    SELECT 'GUEST', (SELECT custtype_code
    from custtype
    where custtype_id = fetchmetricvalue('DefaultCustType')),
    'Guest Customer', TRUE,
    'MAIN-TAXABLE', 'PREPAID', 'Guest', 'Customer', 'XPRESS Defaut Customer for Web Portal',t,t,'WH1'
    WHERE NOT EXISTS (SELECT 1 FROM custinfo WHERE cust_number = 'GUEST');

SELECT setmetric('xDrupleGuestCustomer', (SELECT cust_id::text FROM custinfo WHERE cust_number = 'GUEST'));
SELECT setmetric('xDrupleDefaultPrepayTerms', (SELECT terms_id FROM terms WHERE terms_code = 'NET-30')::text);


-- Insert item Groups for web portal
    INSERT INTO itemgrp (itemgrp_name, itemgrp_descrip, itemgrp_catalog)
    SELECT 'CATALOG', 'XPRESS CATALOG',  TRUE
    WHERE NOT EXISTS (SELECT 1 FROM itemgrp WHERE itemgrp_name = 'CATALOG');

    INSERT INTO itemgrp (itemgrp_name, itemgrp_descrip, itemgrp_catalog)
    SELECT 'XPRESS', 'XPRESS CATALOG',  FALSE
    WHERE NOT EXISTS (SELECT 1 FROM itemgrp WHERE itemgrp_name = 'XPRESS');

    INSERT INTO itemgrpitem (itemgrpitem_itemgrp_id, itemgrpitem_item_id,itemgrpitem_item_type)
    SELECT
    (SELECT itemgrp_id FROM itemgrp WHERE itemgrp_name = 'CATALOG') AS itemgrp_id,
    (SELECT itemgrp_id FROM itemgrp WHERE itemgrp_name = 'XPRESS') AS itemgrpitem_id,'G'
    WHERE NOT EXISTS (SELECT 1 FROM itemgrpitem WHERE itemgrpitem_item_type = 'G');
