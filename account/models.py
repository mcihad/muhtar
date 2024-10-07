from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils.translation import gettext_lazy as _

from .managers import CustomUserManager


class KurumTipChoices(models.IntegerChoices):
    MUHTARLIK = 1, _("Muhtarlık")
    ILCE_OZEL_IDARE = 2, _("İlçe Özel İdaresi")
    IL_OZEL_IDARE = 3, _("İl Özel İdaresi")


class KullaniciTipChoices(models.IntegerChoices):
    MUHTARLIK = 1, _("Muhtarlık")
    ILCE_OZEL_IDARE = 2, _("İlçe Özel İdaresi")
    IL_OZEL_IDARE = 3, _("İl Özel İdaresi")

    SISTEM = 99, _("Sistem")


class Il(models.Model):
    ad = models.CharField(_("İl Adı"), max_length=255)

    def __str__(self):
        return self.ad

    class Meta:
        verbose_name = _("İl")
        verbose_name_plural = _("İller")


class Ilce(models.Model):
    ad = models.CharField(_("İlçe Adı"), max_length=255)
    il = models.ForeignKey(
        Il, on_delete=models.CASCADE, related_name="ilceler", verbose_name=_("İl")
    )

    def __str__(self):
        return self.ad

    class Meta:
        verbose_name = _("İlçe")
        verbose_name_plural = _("İlçeler")


class Kurum(models.Model):
    ad = models.CharField(_("Kurum Adı"), max_length=255)
    yetkili = models.CharField(_("Yetkili"), max_length=100)
    unvan = models.CharField(_("Ünvan"), max_length=100, help_text="Kurumun unvanı")
    adres = models.TextField(_("Adres"), blank=True, null=True)
    telefon = models.CharField(_("Telefon"), max_length=20, blank=True, null=True)
    eposta = models.EmailField(_("E-Posta"), blank=True, null=True)
    il = models.ForeignKey(
        Il, on_delete=models.CASCADE, related_name="kurumlar", verbose_name=_("İl")
    )
    ilce = models.ForeignKey(
        Ilce,
        on_delete=models.CASCADE,
        related_name="kurumlar",
        verbose_name=_("İlçe"),
    )

    tip = models.IntegerField(
        _("Kurum Tipi"),
        choices=KurumTipChoices.choices,
        default=KurumTipChoices.MUHTARLIK,
    )

    def __str__(self):
        return self.ad

    class Meta:
        verbose_name = _("Kurum")
        verbose_name_plural = _("Kurumlar")


class CustomUser(AbstractUser):
    mobile = models.CharField(_("Telefon"), max_length=15, blank=True, null=True)
    kurum = models.ForeignKey(
        Kurum,
        on_delete=models.CASCADE,
        related_name="kullanicilar",
        verbose_name=_("Kurum"),
        blank=True,
        null=True,
    )
    tip = models.IntegerField(
        _("Kullanıcı Tipi"),
        choices=KullaniciTipChoices.choices,
        default=KullaniciTipChoices.MUHTARLIK,
    )
    USERNAME_FIELD = "username"
    REQUIRED_FIELDS = []

    objects = CustomUserManager()

    def __str__(self):
        return f"{self.username} - {self.first_name} {self.last_name}"
