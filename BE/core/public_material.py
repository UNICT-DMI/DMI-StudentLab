"""Compatibilità: il modello PublicMaterial vive in models/public_material.py.

Questo file esisteva come copia aggiornata del modello, ma nessun modulo lo
importava: il codice usava la versione in models/, priva delle colonne del
catalogo (percorso, visibilità, destinatari, Drive). Ora c'è un'unica
definizione; questo modulo la riesporta per chi dovesse ancora importarla da qui.
"""
from models.public_material import PublicMaterial, utc_now  # noqa: F401
