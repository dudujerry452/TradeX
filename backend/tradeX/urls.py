from django.contrib import admin
from django.urls import path, re_path
from django.views.generic import TemplateView

from .api import api

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', api.urls),
    re_path(r'^.*$', TemplateView.as_view(template_name="index.html")),
]
