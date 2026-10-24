"""tricount sync

Groups kept in sync with a tricount (app/modules/tricount_sync): the server's Tricount
device, links, who each Tricount member is, which entry is which (with the version both sides
last agreed on), and conflicts. Users gain the "system" role for the "Tricount" user that
synced changes are recorded as.

Revision ID: 0008_tricount_sync
Revises: 0007_member_invite
Create Date: 2026-10-11
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0008_tricount_sync"
down_revision: str | Sequence[str] | None = "0007_member_invite"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.drop_constraint(op.f("ck_users_role"), "users", type_="check")
    op.create_check_constraint(op.f("ck_users_role"), "users", "role IN ('user', 'admin', 'system')")
    op.create_table('tricount_devices',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('app_id', sa.Text(), nullable=False),
    sa.Column('public_key_pem', sa.Text(), nullable=False),
    sa.Column('token', sa.Text(), nullable=True),
    sa.Column('tricount_user_id', sa.BigInteger(), nullable=True),
    sa.Column('created_at', sa.TIMESTAMP(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_tricount_devices'))
    )
    op.create_table('tricount_links',
    sa.Column('group_id', sa.UUID(), nullable=False),
    sa.Column('public_token', sa.Text(), nullable=False),
    sa.Column('registry_id', sa.BigInteger(), nullable=False),
    sa.Column('currency', sa.CHAR(length=3), nullable=False),
    sa.Column('title_base', sa.Text(), nullable=True),
    sa.Column('created_by', sa.UUID(), nullable=False),
    sa.Column('created_at', sa.TIMESTAMP(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('state', sa.Text(), server_default='syncing', nullable=False),
    sa.Column('last_error', sa.Text(), nullable=True),
    sa.Column('warnings', postgresql.JSONB(astext_type=sa.Text()), server_default=sa.text("'[]'::jsonb"), nullable=False),
    sa.Column('last_synced_at', sa.TIMESTAMP(timezone=True), nullable=True),
    sa.Column('failures', sa.Integer(), server_default='0', nullable=False),
    sa.Column('next_attempt_at', sa.TIMESTAMP(timezone=True), nullable=True),
    sa.Column('lease_until', sa.TIMESTAMP(timezone=True), nullable=True),
    sa.Column('seen_seq', sa.BigInteger(), server_default='0', nullable=False),
    sa.Column('last_active_at', sa.TIMESTAMP(timezone=True), nullable=True),
    sa.CheckConstraint("state IN ('syncing', 'ok', 'error')", name=op.f('ck_tricount_links_state')),
    sa.ForeignKeyConstraint(['created_by'], ['users.id'], name=op.f('fk_tricount_links_created_by_users')),
    sa.ForeignKeyConstraint(['group_id'], ['groups.id'], name=op.f('fk_tricount_links_group_id_groups')),
    sa.PrimaryKeyConstraint('group_id', name=op.f('pk_tricount_links')),
    sa.UniqueConstraint('registry_id', name=op.f('uq_tricount_links_registry_id'))
    )
    op.create_table('tricount_entries',
    sa.Column('id', sa.UUID(), server_default=sa.text('gen_random_uuid()'), nullable=False),
    sa.Column('group_id', sa.UUID(), nullable=False),
    sa.Column('entity', sa.Text(), nullable=False),
    sa.Column('entity_id', sa.UUID(), nullable=False),
    sa.Column('remote_id', sa.BigInteger(), nullable=True),
    sa.Column('base', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    sa.Column('generation', sa.Integer(), server_default='0', nullable=False),
    sa.Column('force', sa.Text(), nullable=True),
    sa.CheckConstraint("entity IN ('expense', 'settlement')", name=op.f('ck_tricount_entries_entity')),
    sa.CheckConstraint("force IN ('push', 'pull')", name=op.f('ck_tricount_entries_force')),
    sa.ForeignKeyConstraint(['group_id'], ['tricount_links.group_id'], name=op.f('fk_tricount_entries_group_id_tricount_links'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_tricount_entries')),
    sa.UniqueConstraint('group_id', 'entity', 'entity_id', name=op.f('uq_tricount_entries_group_id'))
    )
    op.create_index('ix_tricount_entries_remote', 'tricount_entries', ['group_id', 'remote_id'], unique=False)
    op.create_table('tricount_members',
    sa.Column('group_id', sa.UUID(), nullable=False),
    sa.Column('membership_uuid', sa.Text(), nullable=False),
    sa.Column('user_id', sa.UUID(), nullable=False),
    sa.ForeignKeyConstraint(['group_id'], ['tricount_links.group_id'], name=op.f('fk_tricount_members_group_id_tricount_links'), ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], name=op.f('fk_tricount_members_user_id_users')),
    sa.PrimaryKeyConstraint('group_id', 'membership_uuid', name=op.f('pk_tricount_members')),
    sa.UniqueConstraint('group_id', 'user_id', name=op.f('uq_tricount_members_group_id'))
    )
    op.create_table('tricount_conflicts',
    sa.Column('id', sa.UUID(), server_default=sa.text('gen_random_uuid()'), nullable=False),
    sa.Column('group_id', sa.UUID(), nullable=False),
    sa.Column('entry_id', sa.UUID(), nullable=False),
    sa.Column('local', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    sa.Column('remote', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    sa.Column('created_at', sa.TIMESTAMP(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('resolved_at', sa.TIMESTAMP(timezone=True), nullable=True),
    sa.Column('resolved_by', sa.UUID(), nullable=True),
    sa.Column('resolution', sa.Text(), nullable=True),
    sa.CheckConstraint("resolution IN ('splitkit', 'tricount')", name=op.f('ck_tricount_conflicts_resolution')),
    sa.ForeignKeyConstraint(['entry_id'], ['tricount_entries.id'], name=op.f('fk_tricount_conflicts_entry_id_tricount_entries'), ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['group_id'], ['tricount_links.group_id'], name=op.f('fk_tricount_conflicts_group_id_tricount_links'), ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['resolved_by'], ['users.id'], name=op.f('fk_tricount_conflicts_resolved_by_users')),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_tricount_conflicts'))
    )
    op.create_index(op.f('ix_tricount_conflicts_group_id'), 'tricount_conflicts', ['group_id'], unique=False)
    op.create_index('ix_tricount_conflicts_open', 'tricount_conflicts', ['entry_id'], unique=True, postgresql_where=sa.text('resolved_at IS NULL'))


def downgrade() -> None:
    op.drop_index('ix_tricount_conflicts_open', table_name='tricount_conflicts', postgresql_where=sa.text('resolved_at IS NULL'))
    op.drop_index(op.f('ix_tricount_conflicts_group_id'), table_name='tricount_conflicts')
    op.drop_table('tricount_conflicts')
    op.drop_table('tricount_members')
    op.drop_index('ix_tricount_entries_remote', table_name='tricount_entries')
    op.drop_table('tricount_entries')
    op.drop_table('tricount_links')
    op.drop_table('tricount_devices')
    op.execute("UPDATE users SET role = 'user' WHERE role = 'system'")
    op.drop_constraint(op.f("ck_users_role"), "users", type_="check")
    op.create_check_constraint(op.f("ck_users_role"), "users", "role IN ('user', 'admin')")
