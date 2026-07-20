"""Thin reuse of ~/workspace/conn_helper for the gold-regression harness.

Exposes just what the harness needs: the Fusion base URL, a (user, password)
pair for a given credential role, and an ATP queryapp connection for the
read-only BIP relay. No secrets live here -- everything comes from
connections.json via conn_helper.
"""
import sys
sys.path.insert(0, r'C:\Users\Monroe\workspace')
from conn_helper import connect_atp, get_fusion_url, get_fusion_user  # noqa: F401


def fusion_url():
    return get_fusion_url()


def fusion_creds(role='fin_impl'):
    """Return (username, password) for a Fusion credential role.

    role: 'fin_impl' (Financials/Procurement), 'scm_impl' (SCM/Items),
          'hcm_impl' (HCM). Suppliers uses fin_impl for the SOAP call and
          the BIP relay (Procurement tables live under ApplicationDB_FSCM).
    """
    return get_fusion_user(role)


def erp_soap_url():
    """The ERP Integration SOAP service endpoint (loadAndImportData,
    getESSJobStatus, submitESSJobRequest all live here)."""
    return fusion_url().rstrip('/') + '/fscmService/ErpIntegrationService'


def atp_queryapp():
    """oracledb connection to ATP queryapp as DMT_OWNER (hosts the read-only
    BIP relay package FBT_BIP_PKG). Read-only use only."""
    return connect_atp('queryapp', 'DMT_OWNER')
