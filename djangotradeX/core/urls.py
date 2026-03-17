from django.urls import path

from . import views

urlpatterns = [
    path("users/", views.users, name="users"),
    path("users/<str:user_id>/", views.user_detail, name="user_detail"),
    path("products/", views.products, name="products"),
    path("products/<str:product_id>/", views.product_detail, name="product_detail"),
]
