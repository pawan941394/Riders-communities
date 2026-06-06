import re
from typing import Any, Literal

from django.contrib.auth import get_user_model
from django.db import transaction
from django.db.models import QuerySet
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from apps.rider_auth.api import current_user_dep
from apps.wallet.models import Wallet, WalletTransaction, WalletWithdrawalRequest

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


class WalletWithdrawalCreateIn(BaseModel):
    amount: int = Field(ge=100, le=10_000_000_000)
    upi_id: str = Field(min_length=3, max_length=128)
    note: str = Field(default="", max_length=255)


class WalletWithdrawalOut(BaseModel):
    id: int
    amount: int
    upi_id: str
    status: Literal["pending", "processing", "paid", "rejected"]
    user_note: str
    admin_note: str
    debit_transaction_id: int | None
    created_at: str
    updated_at: str
    processed_at: str | None


class WalletWithdrawalCreateResponse(BaseModel):
    message: str
    wallet: WalletOut
    withdrawal: WalletWithdrawalOut
    recent_transactions: list[WalletTxnOut]


class WalletWithdrawalListResponse(BaseModel):
    total: int
    items: list[WalletWithdrawalOut]


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


def _withdrawal_out(row: WalletWithdrawalRequest) -> WalletWithdrawalOut:
    return WalletWithdrawalOut(
        id=row.id,
        amount=row.amount,
        upi_id=row.upi_id,
        status=row.status,
        user_note=row.user_note or "",
        admin_note=row.admin_note or "",
        debit_transaction_id=row.debit_transaction_id,
        created_at=row.created_at.isoformat(),
        updated_at=row.updated_at.isoformat(),
        processed_at=row.processed_at.isoformat() if row.processed_at else None,
    )


def _txns_for_user(user: User) -> QuerySet[WalletTransaction]:
    return WalletTransaction.objects.filter(user=user).order_by("-created_at", "-id")


def _wallet_for_user(user: User) -> Wallet:
    wallet, _ = Wallet.objects.get_or_create(user=user)
    return wallet


def _normalize_upi_id(value: str) -> str:
    upi_id = value.strip().lower()
    if not re.fullmatch(r"[a-z0-9.\-_]{2,}@[a-z0-9.\-_]{2,}", upi_id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please enter a valid UPI ID.",
        )
    return upi_id


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


@router.get("/withdrawals", response_model=WalletWithdrawalListResponse)
def wallet_withdrawals(
    limit: int = 30,
    offset: int = 0,
    user: User = Depends(current_user_dep),
) -> WalletWithdrawalListResponse:
    limit = max(1, min(limit, 200))
    offset = max(0, offset)
    qs = WalletWithdrawalRequest.objects.filter(user=user).order_by("-created_at", "-id")
    total = qs.count()
    rows = list(qs[offset : offset + limit])
    return WalletWithdrawalListResponse(total=total, items=[_withdrawal_out(x) for x in rows])


@router.post("/withdrawals", response_model=WalletWithdrawalCreateResponse)
def wallet_create_withdrawal(
    payload: WalletWithdrawalCreateIn,
    user: User = Depends(current_user_dep),
) -> WalletWithdrawalCreateResponse:
    upi_id = _normalize_upi_id(payload.upi_id)
    note = payload.note.strip()

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

        withdrawal = WalletWithdrawalRequest.objects.create(
            wallet=wallet,
            user=user,
            amount=payload.amount,
            upi_id=upi_id,
            user_note=note,
        )
        debit_transaction = WalletTransaction.objects.create(
            wallet=wallet,
            user=user,
            created_by=user,
            entry_type=WalletTransaction.EntryType.DEBIT,
            amount=payload.amount,
            balance_before=before,
            balance_after=after,
            source="withdrawal_request",
            reason=f"Payout request to UPI {upi_id}",
            reference_id=f"withdrawal:{withdrawal.id}",
            metadata={
                "withdrawal_request_id": withdrawal.id,
                "upi_id": upi_id,
                "status": withdrawal.status,
            },
        )
        withdrawal.debit_transaction = debit_transaction
        withdrawal.save(update_fields=["debit_transaction", "updated_at"])

    recent = list(_txns_for_user(user)[:20])
    return WalletWithdrawalCreateResponse(
        message="Withdrawal request created.",
        wallet=_wallet_out(wallet),
        withdrawal=_withdrawal_out(withdrawal),
        recent_transactions=[_txn_out(x) for x in recent],
    )


@router.post("/withdraw", response_model=WalletWithdrawalCreateResponse)
def wallet_create_withdrawal_alias(
    payload: WalletWithdrawalCreateIn,
    user: User = Depends(current_user_dep),
) -> WalletWithdrawalCreateResponse:
    return wallet_create_withdrawal(payload=payload, user=user)


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

