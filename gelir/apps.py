from django.apps import AppConfig
from django.utils.translation import gettext_lazy as _


class GelirConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "gelir"
    verbose_name = _("Gelir")
