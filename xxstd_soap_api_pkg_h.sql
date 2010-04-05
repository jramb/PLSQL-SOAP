create or replace package xxstd_soap_api_pkg is
--+=======================================================================
--|
--|  $header$
--|
--|   XXSTD SOAP API, Tools to access SOAP webservices
--|
--| With great influence from http://www.oracle-base.com/dba/miscellaneous/soap_api.sql
--| Original author: DR Timothy S Hall
--| 2008-2010 Rewrite by J Ramb
--|
--+=======================================================================


function generate_envelope(p_body in xmltype := null)
  return xmltype;


procedure invoke(
  p_url         in varchar2,
  p_action      in varchar2,
  p_body_xml    in xmltype,
  p_body_clob   in CLOB,
  p_return_type in varchar2, -- 'XML'/'CLOB'
  p_return_xml  out xmltype,
  p_return_clob out CLOB,
  p_proxy_username in varchar2 := null,
  p_proxy_password in varchar2 := null
  );


function invoke(
  p_url     in             varchar2,
  p_action  in             varchar2,
  p_body    in             XMLTYPE)
return XMLTYPE;


function invoke(
  p_url     in             varchar2,
  p_action  in             varchar2,
  p_body    in             CLOB)
return CLOB;

end xxstd_soap_api_pkg;
/

sho err

