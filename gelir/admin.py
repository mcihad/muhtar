from django.contrib import admin
from django.utils.translation import gettext_lazy as _

from .models import Abone, AboneTip, GelirTip, Mukellef, SuTahakkuk, SuTarife


@admin.register(GelirTip)
class GelirTipAdmin(admin.ModelAdmin):
    list_display = ("ad", "muhasebe_kodu", "ekleyen", "kurum_id")
    list_filter = ("ekleyen",)
    search_fields = ("ad", "muhasebe_kodu")


@admin.register(AboneTip)
class AboneTipAdmin(admin.ModelAdmin):
    list_display = ("ad",)
    search_fields = ("ad",)


@admin.register(Mukellef)
class MukellefAdmin(admin.ModelAdmin):
    list_display = (
        "mukellef_no",
        "ad",
        "soyad",
        "tc_no",
        "baba_ad",
        "anne_ad",
    )
    list_filter = ("cinsiyet", "medeni_durum", "egitim_durumu")
    search_fields = ("ad", "soyad", "tc_no")


@admin.register(Abone)
class AboneAdmin(admin.ModelAdmin):
    list_display = ("abone_no", "ad", "soyad", "abone_tip")
    list_filter = ("abone_tip",)
    search_fields = ("abone_no", "ad", "soyad")


@admin.register(SuTarife)
class SuTarifeAdmin(admin.ModelAdmin):
    list_display = ("kurum", "abone_tip", "ilk_endeks", "son_endeks", "tarife")
    list_filter = ("abone_tip", "kurum")


@admin.register(SuTahakkuk)
class SuTahakkukAdmin(admin.ModelAdmin):
    list_display = (
        "abone",
        "ilk_endeks",
        "son_endeks",
        "tuketim",
        "toplam_tutar",
        "tahakkuk_tarihi",
        "son_odeme_tarihi",
        "durum",
    )
    list_filter = ("tahakkuk_tarihi", "tahakkuk_tarihi", "durum")
