create or replace package body xxstd_soap_api_pkg is
--+=======================================================================
--|
--|  $header$
--|
--|   XXSTD SOAP API, Tools to access SOAP webservices
--|   2008-2010 by J Ramb
--|
--+=======================================================================


/** EXAMPLE:  --{{{

declare
  v_req_xml   xmltype;
  v_resp_xml  xmltype;
  v_req_clob  CLOB;
  v_resp_clob  CLOB;
  v_start_time          number;
begin
  -- Set proxy details if no direct net connection.
  --UTL_HTTP.set_proxy('myproxy:4480', NULL);
  --UTL_HTTP.set_persistent_conn_support(TRUE);


  -- Set proxy authentication if necessary.
  --xxstd_soap_api_pkg.set_proxy_authentication(p_username => 'myusername',
  --                                  p_password => 'mypassword');

  utl_http.set_transfer_timeout(1000); -- 1000 seconds, default is 60!

  v_req_xml := xmltype('
<ska:GetProjectMaster xmlns="http://www.openapplications.org/oagis/9"
                      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                      xmlns:ska="http://www.example.se/oagis/9"
                      xsi:schemaLocation="http://www.example.se/oagis/9 ../BODs/GetProjectMaster.xsd"
                      versionID="1.0"
                      releaseID="9.0"
                      systemEnvironmentCode="UTV">
  <ApplicationArea>
    <ska:Sender>
      <LogicalID>OEBS_SE</LogicalID>
      <ComponentID>YourContractID</ComponentID>
      <!--AuthorizationID>RAMBJ</AuthorizationID-->
      <!--ska:ResponsibilityID>50092</ska:ResponsibilityID-->
    </ska:Sender>
    <CreationDateTime>2007-02-15</CreationDateTime>
    <BODID>ContractID+unique traceable id from the sending system (for this transaction)</BODID>
  </ApplicationArea>
  <DataArea>
    <Get maxItems="10">
      <Expression expressionLanguage="level">LIST<!-- FULL LIST SPIK BASIC --></Expression>
      <Expression expressionLanguage="params">NOTASKS</Expression>
    </Get>
    <ska:ProjectMaster>
      <ID schemeName="ProjectNumber"><!--112675--></ID>
      <ID schemeName="ProjectID"><!--30427--></ID>
      <AuthorizationID>RAMBJ</AuthorizationID>
      <ska:ProjectActivity>
            <ID schemeName="TaskID"><!--570731--></ID>
            <ID schemeName="TaskNumber"><!--10--></ID>
      </ska:ProjectActivity>
      <ska:ResponsibilityID><!--50092Modulansvarig Projekt-K SVE--></ska:ResponsibilityID>
    </ska:ProjectMaster>
  </DataArea>
</ska:GetProjectMaster>
');

--for i in 1..10 loop
  v_start_time := dbms_utility.get_time;
  v_resp_xml := xxstd_soap_api_pkg.invoke(
    p_url     => '()http://ska536.data.example.se:7779/XXPA140B/ProjectMasterPort',
    p_action  => 'GetProjectMaster',
    p_body    => v_req_xml);
  v_resp_xml := v_resp_xml.extract('/ska:ShowProjectMaster/DataArea/Show/@recordSetCount',
    xxstd_oagis_tools_pkg.SCHEMA_NS);
  dbms_output.put_line('Number of projects: '||
    v_resp_xml.getStringVal()||
    ', time taken: '||( (dbms_utility.get_time - v_start_time)/100 ));
--end loop;


--  declare
--    v_clob CLOB := v_resp_xml.extract('/'||'*').getClobVal();
--    v_buffer  varchar2(4096);
--    v_size    number := 4096;
--    v_offset  number := 1;
--  begin
--    loop
--      dbms_lob.read(v_clob, v_size, v_offset, v_buffer);
--      dbms_output.put_line(v_buffer);
--      v_offset := v_offset + v_size;
--    end loop;
--  exception when no_data_found then null;
--  end;

end;
*/ ---}}}







function generate_envelope(p_body in xmltype := null) --{{{
  return xmltype
is
 v_xml xmltype;
begin
  select xmlelement("soap:Envelope", xmlattributes('http://schemas.xmlsoap.org/soap/envelope/' as "xmlns:soap",
    'http://www.w3.org/1999/XMLSchema-instance' as "xmlns:xsi",
    'http://www.w3.org/1999/XMLSchema' as "xmlns:xsd"),
      xmlelement("soap:Body", nvl(p_body, xmlcomment('REPLACEME'))))
        into v_xml
        from dual;
  return v_xml;
END;  --}}}
-- ---------------------------------------------------------------------




procedure check_fault(p_response in out nocopy xmltype) --{{{
is
  l_fault_node    XMLTYPE;
  --l_part          xmltype;
  --l_fault_code    VARCHAR2(256);
  --l_fault_string  VARCHAR2(32767);
begin
  --G_SOAP_FAULT := l_fault_node;
  if p_response is null then
    raise_application_error(-20003, 'Empty SOAP body!');
  end if;
  l_fault_node := p_response.extract('/soap:Envelope/soap:Body/soap:Fault',
                                         'xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"');
  if l_fault_node is null then
    l_fault_node := p_response.extract('/soap:Envelope/soap:Body/soap:Fault',
                                         'xmlns:soap="http://www.w3.org/2003/05/soap-envelope"');
  end if;
  if (l_fault_node is not null) then
    --G_SOAP_FAULT := l_fault_node;
    /*
    l_part         := l_fault_node.extract('/soap:Fault/faultcode/child::text()', 'xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"');
    if l_part is not null then
      l_fault_code   := l_part.getStringVal();
    end if;
    l_part         := l_fault_node.extract('/soap:Fault/faultstring/child::text()', 'xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"');
    if l_part is not null then
      l_fault_string := l_part.getStringVal();
    end if;
    */
    --raise_application_error(-20000, l_fault_code || ' - ' || l_fault_string);
    raise_application_error(-20000, substr(l_fault_node.getClobVal(),1,2000));
  end if;
end;  --}}}


procedure hlp_write_clob( --{{{
  p_http_request in out nocopy utl_http.req,
  p_clob in CLOB)
is
  v_buffer  varchar2(4096);
  v_size    number := 4096;
  v_offset  number := 1;
begin
  loop
    dbms_lob.read(p_clob, v_size, v_offset, v_buffer);
    UTL_HTTP.write_text(p_http_request, v_buffer);
    v_offset := v_offset + v_size;
  end loop;
exception when no_data_found then
  null;
end hlp_write_clob; --}}}


procedure hlp_read_clob(  --{{{
  p_http_response in out nocopy utl_http.resp,
  p_clob  in out nocopy CLOB)
is
  v_buffer varchar2(4096);
  v_size   number := 4096;
begin
--  dbms_lob.createtemporary(p_clob, false);
  loop
    UTL_HTTP.read_text(r => p_http_response, data => v_buffer);
    dbms_lob.writeappend( p_clob, length(v_buffer), v_buffer);
  end loop;
exception
  when utl_http.end_of_body then
    NULL;
end hlp_read_clob;  --}}}




-- Generic version, allows both input be XML or CLOB
-- and the output as XML/CLOB.
-- The parameter p_body_XX that is not null is the input
-- and the type of output is specified by the p_return_type
-- p_return_clob must be freed by the caller: dbms_lob.freetemporary(clob)
procedure invoke( --{{{
  p_url         in varchar2,
  p_action      in varchar2,
  p_body_xml    in xmltype,
  p_body_clob   in CLOB,
  p_return_type in varchar2, -- 'XML'/'CLOB'
  p_return_xml  out xmltype,
  p_return_clob out CLOB,
  p_proxy_username in varchar2 := null,
  p_proxy_password in varchar2 := null
  )
is
  v_database_name   varchar2(100);

  v_request_clob    CLOB;
  v_respond_clob    CLOB;
  v_http_request    UTL_HTTP.req;
  v_http_response   UTL_HTTP.resp;
  v_response_xml    xmltype;
  v_response_body   xmltype;
  v_is_clob_request boolean;
  v_request_template  varchar2(2000) := null;
  v_request_len     number := 0;
  v_charset         varchar2(50);
  v_xml_decl        varchar2(100);
  v_start_time      number;

  C_REPLACE CONSTANT varchar2(100) := '<!--REPLACEME-->';
begin
  if p_body_xml is null and p_body_clob is null then
    raise_application_error(-20001, 'No body provided, aborting.');
  end if;
  if p_body_xml is not null and p_body_clob is not null then
    raise_application_error(-20001, 'Multiple bodies provided, aborting.');
  end if;

  select name
    into v_database_name
    from v$database;

  v_is_clob_request := (p_body_xml is null);
  if v_is_clob_request then
    --generate the envelope with "<!--REPLACEME-->" where the contents would be.
    --this is short, so a varchar2 is sufficient
    v_request_template := generate_envelope(NULL).getStringVal();
--DOES NOT WORK:    v_request_clob := replace(v_request_clob,'<!--REPLACEME-->',p_body_clob); -- FIXME? does this work for larger stuff?
    v_request_len := dbms_lob.getLength(p_body_clob) + length(v_request_template) - length(C_REPLACE);
  else
    v_request_clob := generate_envelope(p_body_xml).getClobVal();
    v_request_len := dbms_lob.getLength(v_request_clob);
  end if;

  -- feature (security)
  -- The URL must be in the style "(NNNN)http://webservice..."
  -- where NNNN is the database name!
  -- This is a safety feature! It has a meaning (and saved me a couple of times).
  if regexp_replace(p_url,'^(\(.*\)).*$','\1') not in ('('||v_database_name||')') then
    raise_application_error(-20004,'Url must be prefixed with "(<DBNAME>)"');
  end if;


  v_http_request := UTL_HTTP.begin_request(substr(p_url,instr(p_url,')')+1), 'POST','HTTP/1.1'); -- Bug? 1.0?
  IF p_proxy_username IS NOT NULL THEN
    UTL_HTTP.set_authentication(r         => v_http_request,
                                username  => p_proxy_username,
                                password  => p_proxy_password,
                                scheme    => 'Basic',
                                for_proxy => TRUE);
  END IF;

  v_start_time := dbms_utility.get_time;
  v_charset:='ISO-8859-1';  -- NICE-to-have: check dbs setup instead? how?
  v_xml_decl := '<?xml version="1.0" encoding="'||v_charset||'"?>'||chr(13)||chr(10);
  v_request_len := v_request_len+length(v_xml_decl);
  UTL_HTTP.set_header(v_http_request, 'User-Agent', 'OADB xxstd_soap_api_pkg ('||v_database_name||')');
  UTL_HTTP.set_header(v_http_request, 'Content-Type', 'text/xml;charset='||v_charset);
  UTL_HTTP.set_header(v_http_request, 'Content-Length', to_char(v_request_len));
  UTL_HTTP.set_header(v_http_request, 'SOAPAction', p_action);

  UTL_HTTP.write_text(v_http_request,v_xml_decl);
  if v_is_clob_request then
    UTL_HTTP.write_text(v_http_request,
      substr(v_request_template,1,instr(v_request_template,C_REPLACE)-1));        -- first part of envelope
    hlp_write_clob(v_http_request, p_body_clob);  -- body
    UTL_HTTP.write_text(v_http_request,
      substr(v_request_template,instr(v_request_template,C_REPLACE)+
        length(C_REPLACE)));        -- last part of envelope
  else
    -- just put out the request_clob
    hlp_write_clob(v_http_request, v_request_clob);
  end if;
  v_http_response := UTL_HTTP.get_response(v_http_request);

  dbms_lob.createtemporary(v_respond_clob, false);
  hlp_read_clob(v_http_response, v_respond_clob);
  UTL_HTTP.end_response(v_http_response);

  --if( nvl(fnd_profile.value_WNPS/*no cache*/('XXSTD_SOAP_API_TIMER'),'Y')='Y') then
    --xxstd_key_values_pkg.set_number(
      --p_domain => 'XXSTD_SOAP_API'
      --, p_entity_type => 'START_TIME'
      --, p_entity_id => v_start_time
      --, p_key => p_url
      --, p_value => (dbms_utility.get_time - v_start_time)/100
      --);
  --end if;
  if p_return_type='XML' then
    v_response_xml := XMLTYPE.createxml(v_respond_clob);
    dbms_lob.freetemporary(v_respond_clob);
--    dbms_output.put_line(v_response_xml.getStringVal());-- DEBUG
    check_fault(v_response_xml);
    v_response_body := v_response_xml.extract('/soap:Envelope/soap:Body/*', --child::node()',
                                             'xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"');
    if v_response_body is null then
      v_response_body := v_response_xml.extract('/soap:Envelope/soap:Body/*', --child::node()',
                                             'xmlns:soap="http://www.w3.org/2003/05/soap-envelope"');
    end if;
    if v_response_body is null then
      raise_application_error(-20005, 'SOAP call failed: '||substr(v_response_xml.getClobVal(),1,1000));
    end if;
    p_return_xml := v_response_body;
  elsif p_return_type='CLOB' then
    -- just return the plain answer
    p_return_clob := v_respond_clob;
  else
    raise_application_error(-20002, 'Invalid return type: '||p_return_type);
  end if;
end invoke; --}}}




-- helper function: invoke that talks only xmltype
function invoke(  --{{{
  p_url     in varchar2,
  p_action  in varchar2,
  p_body    in XMLTYPE)
return XMLTYPE
is
  v_response_xml    xmltype;
  v_dummy_clob      CLOB;
begin
  invoke(
    p_url         => p_url,
    p_action      => p_action,
    p_body_xml    => p_body,
    p_body_clob   => NULL,
    p_return_type => 'XML',
    p_return_xml  => v_response_xml,
    p_return_clob => v_dummy_clob);
  return v_response_xml;
end invoke; --}}}



-- helper function: invoke that talks only CLOB
function invoke(  --{{{
  p_url     in             varchar2,
  p_action  in             varchar2,
  p_body    in             CLOB)
return CLOB as
  v_response_clob   CLOB;
  v_dummy_xml       xmltype;
BEGIN
  invoke(
    p_url         => p_url,
    p_action      => p_action,
    p_body_xml    => null,
    p_body_clob   => p_body,
    p_return_type => 'CLOB',
    p_return_xml  => v_dummy_xml,
    p_return_clob => v_response_clob);
  return v_response_clob;
end invoke; --}}}






end xxstd_soap_api_pkg;
/

sho err

