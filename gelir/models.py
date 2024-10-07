from django.db import models
from django.utils.translation import gettext_lazy as _

from account.models import Kurum


class EkleyenChoices(models.IntegerChoices):
    SISTEM = 1, _("Sistem")
    KULLANICI = 2, _("Kullanıcı")


class CinsiyetChoices(models.IntegerChoices):
    ERKEK = 1, _("Erkek")
    KADIN = 2, _("Kadın")


class MedeniDurumChoices(models.IntegerChoices):
    EVLI = 1, _("Evli")
    BEKAR = 2, _("Bekar")
    DUL = 3, _("Dul")
    BOSANMIS = 4, _("Boşanmış")


class EgitimDurumuChoices(models.IntegerChoices):
    ILKOKUL = 1, _("İlkokul")
    ORTAOKUL = 2, _("Ortaokul")
    LISE = 3, _("Lise")
    ONLISANS = 4, _("Önlisans")
    LISANS = 5, _("Lisans")
    YUKSEKLISANS = 6, _("Yüksek Lisans")
    DOKTORA = 7, _("Doktora")


class SayacDurumChoices(models.IntegerChoices):
    NORMAL = 1, _("Normal")
    TERS = 2, _("Ters")
    ARIZALI = 3, _("Arızalı")
    OKUNAMIYOR = 4, _("Okunamıyor")
    DIGER = 99, _("Diğer")


class GelirTip(models.Model):

    ad = models.CharField(_("Ad"), max_length=255)
    muhasebe_kodu = models.CharField(
        _("Muhasebe Kodu"), max_length=255, blank=True, null=True
    )
    ekleyen = models.IntegerField(
        _("Ekleyen"),
        choices=EkleyenChoices.choices,
        default=EkleyenChoices.SISTEM,
    )
    kurum_id = models.IntegerField(_("Kurum ID"), blank=True, null=True, default=0)

    class Meta:
        verbose_name = _("Gelir Tip")
        verbose_name_plural = _("Gelir Tipleri")

    def __str__(self):
        return self.ad


class AboneTip(models.Model):
    ad = models.CharField(_("Ad"), max_length=255)
    aciklama = models.TextField(_("Açıklama"), blank=True, null=True)

    class Meta:
        verbose_name = _("Abone Tip")
        verbose_name_plural = _("Abone Tipleri")

    def __str__(self):
        return self.ad


class Mukellef(models.Model):
    kurum = models.ForeignKey(
        Kurum,
        verbose_name=_("Kurum"),
        on_delete=models.CASCADE,
        related_name="mukellefler",
    )
    mukellef_no = models.CharField(_("Mükellef No"), max_length=20)
    ad = models.CharField(_("Ad"), max_length=255)
    soyad = models.CharField(_("Soyad"), max_length=255)
    tc_no = models.CharField(_("TC No"), max_length=11, blank=True, null=True)
    baba_ad = models.CharField(_("Baba Adı"), max_length=255, blank=True, null=True)
    anne_ad = models.CharField(_("Anne Adı"), max_length=255, blank=True, null=True)
    dogum_tarihi = models.DateField(_("Doğum Tarihi"), blank=True, null=True)
    dogum_yeri = models.CharField(
        _("Doğum Yeri"), max_length=255, blank=True, null=True
    )
    cinsiyet = models.IntegerField(
        _("Cinsiyet"), choices=CinsiyetChoices.choices, blank=True, null=True
    )
    medeni_durum = models.IntegerField(
        _("Medeni Durum"), choices=MedeniDurumChoices.choices, blank=True, null=True
    )
    egitim_durumu = models.IntegerField(
        _("Eğitim Durumu"), choices=EgitimDurumuChoices.choices, blank=True, null=True
    )
    adres = models.TextField(_("Adres"), blank=True, null=True)
    telefon = models.CharField(_("Telefon"), max_length=15, blank=True, null=True)
    email = models.EmailField(_("E-Mail"), blank=True, null=True)
    aktif = models.BooleanField(_("Aktif"), default=True)

    created_at = models.DateTimeField(_("Oluşturulma Tarihi"), auto_now_add=True)
    updated_at = models.DateTimeField(_("Güncelleme Tarihi"), auto_now=True)

    class Meta:
        verbose_name = _("Mükellef")
        verbose_name_plural = _("Mükellefler")
        indexes = [
            models.Index(fields=["ad", "soyad"]),
            models.Index(fields=["mukellef_no"]),
        ]

    def __str__(self):
        return f"{self.ad} {self.soyad}"


class Abone(models.Model):
    kurum = models.ForeignKey(
        Kurum,
        verbose_name=_("Kurum"),
        on_delete=models.CASCADE,
        related_name="aboneler",
    )
    mukellef = models.ForeignKey(
        Mukellef,
        verbose_name=_("Mükellef"),
        on_delete=models.CASCADE,
        related_name="aboneler",
    )
    abone_tip = models.ForeignKey(
        AboneTip,
        verbose_name=_("Abone Tip"),
        on_delete=models.CASCADE,
        related_name="aboneler",
    )
    abone_no = models.CharField(_("Abone No"), max_length=20)
    ad = models.CharField(_("Ad"), max_length=255)
    soyad = models.CharField(_("Soyad"), max_length=255)
    tc_no = models.CharField(_("TC No"), max_length=11, blank=True, null=True)
    baba_ad = models.CharField(_("Baba Adı"), max_length=255, blank=True, null=True)
    anne_ad = models.CharField(_("Anne Adı"), max_length=255, blank=True, null=True)
    adres = models.TextField(_("Adres"), blank=True, null=True)
    sayac_marka = models.CharField(
        _("Sayaç Marka"), max_length=255, blank=True, null=True
    )
    sayac_seri_no = models.CharField(
        _("Sayaç Seri No"), max_length=255, blank=True, null=True
    )
    sayac_durum = models.IntegerField(
        _("Sayaç Durum"),
        choices=SayacDurumChoices.choices,
        default=SayacDurumChoices.NORMAL,
    )
    endeks = models.IntegerField(
        _("Endeks"),
        blank=True,
        null=True,
        default=0,
        help_text="Sayaç endeksi. Sadece ilk kaydederken girilir.",
    )
    aciklama = models.TextField(_("Açıklama"), blank=True, null=True)
    aktif = models.BooleanField(_("Aktif"), default=True)

    created_at = models.DateTimeField(_("Oluşturulma Tarihi"), auto_now_add=True)
    updated_at = models.DateTimeField(_("Güncelleme Tarihi"), auto_now=True)

    class Meta:
        verbose_name = _("Abone")
        verbose_name_plural = _("Aboneler")
        indexes = [
            models.Index(fields=["ad", "soyad"]),
            models.Index(fields=["abone_no"]),
        ]

    def __str__(self):
        return f"{self.ad} {self.soyad}"


class SuTarife(models.Model):
    kurum = models.ForeignKey(
        Kurum,
        verbose_name=_("Kurum"),
        on_delete=models.CASCADE,
        related_name="tarifeler",
    )
    abone_tip = models.ForeignKey(
        AboneTip,
        verbose_name=_("Abone Tip"),
        on_delete=models.CASCADE,
        related_name="tarifeler",
    )
    ilk_endeks = models.IntegerField(_("İlk Endeks"), default=0)
    son_endeks = models.IntegerField(_("Son Endeks"), default=0)
    tarife = models.DecimalField(_("Tarife"), max_digits=5, decimal_places=2)

    class Meta:
        verbose_name = _("Su Tarife")
        verbose_name_plural = _("Su Tarifeleri")

    def __str__(self):
        return f"{self.abone_tip} - {self.tarife}"


class TahakkukDurumChoices(models.IntegerChoices):
    BEKLEMEDE = 1, _("Beklemede")
    ODENDI = 2, _("Ödendi")
    PARCALI_ODENDI = 3, _("Parçalı Ödendi")
    IADE = 4, _("İade")
    IPTAL = 5, _("İptal")
    DIGER = 99, _("Diğer")


class SuTahakkuk(models.Model):
    abone = models.ForeignKey(
        Abone,
        verbose_name=_("Abone"),
        on_delete=models.CASCADE,
        related_name="tahakkuklar",
    )

    ilk_endeks = models.IntegerField(_("İlk Endeks"), default=0)
    son_endeks = models.IntegerField(_("Son Endeks"), default=0)
    tuketim = models.IntegerField(_("Tüketim"), default=0)
    toplam_tutar = models.DecimalField(
        _("Toplam Tutar"), max_digits=10, decimal_places=2
    )
    tahakkuk_tarihi = models.DateField(_("Tahakkuk Tarihi"))
    son_odeme_tarihi = models.DateField(_("Son Ödeme Tarihi"), blank=True, null=True)
    durum = models.IntegerField(
        _("Durum"),
        choices=TahakkukDurumChoices.choices,
        default=TahakkukDurumChoices.BEKLEMEDE,
    )

    hesaplama = models.TextField(_("Hesaplama"), blank=True, null=True)

    created_at = models.DateTimeField(_("Oluşturulma Tarihi"), auto_now_add=True)
    updated_at = models.DateTimeField(_("Güncelleme Tarihi"), auto_now=True)

    class Meta:
        verbose_name = _("Su Tahakkuk")
        verbose_name_plural = _("Su Tahakkuklar")

    def __str__(self):
        return f"{self.abone} - {self.tahakkuk_tarihi}"
