from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .forms import CustomUserChangeForm, CustomUserCreationForm
from .models import CustomUser, Il, Ilce, Kurum


class IlceListFilter(admin.SimpleListFilter):
    title = "İlçe"
    parameter_name = "il__id__exact"

    def lookups(self, request, model_admin):
        if request.GET.get("il__id__exact"):
            return Ilce.objects.filter(
                il_id=request.GET.get("il__id__exact")
            ).values_list("id", "ad")
        return []

    def queryset(self, request, queryset):
        if self.value():
            return queryset.filter(ilce_id=self.value())
        return queryset


@admin.register(Il)
class IlAdmin(admin.ModelAdmin):
    list_display = ["ad"]
    search_fields = ["ad"]


@admin.register(Ilce)
class IlceAdmin(admin.ModelAdmin):
    list_display = ["ad", "il"]
    search_fields = ["ad"]
    list_filter = ["il"]
    list_select_related = ["il"]


@admin.register(Kurum)
class KurumAdmin(admin.ModelAdmin):
    list_display = ["ad", "yetkili", "unvan", "il", "ilce"]
    search_fields = ["ad"]
    list_select_related = ["il", "ilce"]
    autocomplete_fields = ["il", "ilce"]

    def get_list_filter(self, request):
        # if request GET has il parameter return ilce filter else il filter
        if request.GET.get("il__id__exact"):
            return [IlceListFilter]
        return ["il"]


@admin.register(CustomUser)
class CustomUserAdmin(UserAdmin):
    add_form = CustomUserCreationForm
    form = CustomUserChangeForm
    model = CustomUser
    list_select_related = ["kurum"]
    autocomplete_fields = ["kurum"]
    list_display = (
        "username",
        "first_name",
        "last_name",
        "kurum",
        "is_staff",
        "is_active",
    )
    list_filter = (
        "tip",
        "is_staff",
        "is_active",
    )
    fieldsets = (
        (None, {"fields": ("username", "password")}),
        (
            "Permissions",
            {
                "fields": (
                    "kurum",
                    "tip",
                    "first_name",
                    "last_name",
                    "mobile",
                    "email",
                    "is_staff",
                    "is_active",
                )
            },
        ),
    )
    add_fieldsets = (
        (
            None,
            {
                "classes": ("wide",),
                "fields": (
                    "username",
                    "password1",
                    "password2",
                    "first_name",
                    "last_name",
                    "mobile",
                    "email",
                    "is_staff",
                    "is_active",
                    "kurum",
                    "tip",
                ),
            },
        ),
    )
    search_fields = ("username",)
    ordering = ("username",)


admin.site.site_header = "Muhtarlık Yönetim Paneli"
admin.site.site_title = "Muhtarlık Yönetim Paneli"
