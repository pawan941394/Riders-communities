from typing import Any, Literal

from django.contrib.auth import get_user_model
from django.db import transaction
from django.db.models import QuerySet
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from apps.rider_auth.api import current_user_dep
from apps.wallet.models import Wallet, WalletTransaction

router = APIRouter(prefix="/wallet", tags=["Wallet"])
User = get_user_model()


class WalletOut(BaseModel):
    wallet_id: int
    user_id: int
    balance_credits: int
    lifetime_credited: int
    lifetime_debited: int
    updated_at: str


class WalletTxnOut(BaseModel):
    id: int
    entry_type: Literal["credit", "debit"]
    amount: int
    balance_before: int
    balance_after: int
    source: str
    reason: str
    reference_id: str
    metadata: dict[str, Any]
    created_at: str


class WalletMeResponse(BaseModel):
    wallet: WalletOut
    recent_transactions: list[WalletTxnOut]


class WalletTxnListResponse(BaseModel):
    total: int
    items: list[WalletTxnOut]


class WalletAdjustIn(BaseModel):
    amount: int = Field(gt=0, le=10_000_000_000)
    source: str = Field(min_length=2, max_length=64)
    reason: str = Field(default="", max_length=255)
    reference_id: str = Field(default="", max_length=128)
    metadata: dict[str, Any] = Field(default_factory=dict)


def _wallet_out(wallet: Wallet) -> WalletOut:
    return WalletOut(
        wallet_id=wallet.id,
        user_id=wallet.user_id,
        balance_credits=wallet.balance_credits,
        lifetime_credited=wallet.lifetime_credited,
        lifetime_debited=wallet.lifetime_debited,
        updated_at=wallet.updated_at.isoformat(),
    )


def _txn_out(row: WalletTransaction) -> WalletTxnOut:
    return WalletTxnOut(
        id=row.id,
        entry_type=row.entry_type,
        amount=row.amount,
        balance_before=row.balance_before,
        balance_after=row.balance_after,
        source=row.source,
        reason=row.reason or "",
        reference_id=row.reference_id or "",
        metadata=row.metadata or {},
        created_at=row.created_at.isoformat(),
    )


def _txns_for_user(user: User) -> QuerySet[WalletTransaction]:
    return WalletTransaction.objects.filter(user=user).order_by("-created_at", "-id")


def _wallet_for_user(user: User) -> Wallet:
    wallet, _ = Wallet.objects.get_or_create(user=user)
    return wallet


@router.get("/me", response_model=WalletMeResponse)
def wallet_me(user: User = Depends(current_user_dep)) -> WalletMeResponse:
    wallet = _wallet_for_user(user)
    recent = list(_txns_for_user(user)[:20])
    return WalletMeResponse(
        wallet=_wallet_out(wallet),
        recent_transactions=[_txn_out(x) for x in recent],
    )


@router.get("/transactions", response_model=WalletTxnListResponse)
def wallet_transactions(
    limit: int = 30,
    offset: int = 0,
    user: User = Depends(current_user_dep),
) -> WalletTxnListResponse:
    limit = max(1, min(limit, 200))
    offset = max(0, offset)
    qs = _txns_for_user(user)
    total = qs.count()
    rows = list(qs[offset : offset + limit])
    return WalletTxnListResponse(total=total, items=[_txn_out(x) for x in rows])


@router.post("/credit", response_model=WalletMeResponse)
def wallet_credit(
    payload: WalletAdjustIn,
    user: User = Depends(current_user_dep),
) -> WalletMeResponse:
    with transaction.atomic():
        wallet = Wallet.objects.select_for_update().filter(user=user).first()
        if wallet is None:
            wallet = Wallet.objects.create(user=user)

        before = wallet.balance_credits
        after = before + payload.amount
        wallet.balance_credits = after
        wallet.lifetime_credited = wallet.lifetime_credited + payload.amount
        wallet.save(update_fields=["balance_credits", "lifetime_credited", "updated_at"])

        WalletTransaction.objects.create(
            wallet=wallet,
            user=user,
            created_by=user,
            entry_type=WalletTransaction.EntryType.CREDIT,
            amount=payload.amount,
            balance_before=before,
            balance_after=after,
            source=payload.source.strip(),
            reason=payload.reason.strip(),
            reference_id=payload.reference_id.strip(),
            metadata=payload.metadata,
        )

    recent = list(_txns_for_user(user)[:20])
    return WalletMeResponse(
        wallet=_wallet_out(wallet),
        recent_transactions=[_txn_out(x) for x in recent],
    )


@router.post("/debit", response_model=WalletMeResponse)
def wallet_debit(
    payload: WalletAdjustIn,
    user: User = Depends(current_user_dep),
) -> WalletMeResponse:
    with transaction.atomic():
        wallet = Wallet.objects.select_for_update().filter(user=user).first()
        if wallet is None:
            wallet = Wallet.objects.create(user=user)

        before = wallet.balance_credits
        if payload.amount > before:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient wallet balance. Current balance: {before}",
            )

        after = before - payload.amount
        wallet.balance_credits = after
        wallet.lifetime_debited = wallet.lifetime_debited + payload.amount
        wallet.save(update_fields=["balance_credits", "lifetime_debited", "updated_at"])

        WalletTransaction.objects.create(
            wallet=wallet,
            user=user,
            created_by=user,
            entry_type=WalletTransaction.EntryType.DEBIT,
            amount=payload.amount,
            balance_before=before,
            balance_after=after,
            source=payload.source.strip(),
            reason=payload.reason.strip(),
            reference_id=payload.reference_id.strip(),
            metadata=payload.metadata,
        )

    recent = list(_txns_for_user(user)[:20])
    return WalletMeResponse(
        wallet=_wallet_out(wallet),
        recent_transactions=[_txn_out(x) for x in recent],
    )

