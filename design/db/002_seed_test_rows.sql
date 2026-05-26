-- Test data for the library schema.
-- Run after 001_create_tables.sql.
-- This inserts one row per table. The same test user is reused for role-based
-- foreign keys so the seed stays minimal and relationally complete.

begin;

insert into public.users (
    id,
    email,
    password_hash,
    full_name,
    phone,
    address,
    role,
    status,
    email_verified_at,
    joined_at
) values (
    '00000000-0000-4000-8000-000000000001',
    'test.user@example.com',
    crypt('Password123!', gen_salt('bf')),
    'Test User',
    '0900000000',
    '123 Test Street',
    'READER',
    'ACTIVE',
    now(),
    now()
) on conflict (id) do update set
    email = excluded.email,
    password_hash = excluded.password_hash,
    full_name = excluded.full_name,
    phone = excluded.phone,
    address = excluded.address,
    role = excluded.role,
    status = excluded.status,
    email_verified_at = excluded.email_verified_at,
    joined_at = excluded.joined_at;

insert into public.email_verification_tokens (
    id,
    user_id,
    token_hash,
    expires_at,
    used_at
) values (
    '00000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-000000000001',
    encode(digest('test-email-verification-token', 'sha256'), 'hex'),
    now() + interval '24 hours',
    now()
) on conflict (id) do update set
    user_id = excluded.user_id,
    token_hash = excluded.token_hash,
    expires_at = excluded.expires_at,
    used_at = excluded.used_at;

insert into public.categories (
    id,
    name
) values (
    '00000000-0000-4000-8000-000000000003',
    'Software Engineering'
) on conflict (id) do update set
    name = excluded.name;

insert into public.books (
    id,
    category_id,
    created_by_user_id,
    updated_by_user_id,
    title,
    author,
    publication_year,
    isbn,
    description,
    total_copies,
    available_copies,
    borrowed_copies,
    lost_copies,
    damaged_copies,
    status
) values (
    '00000000-0000-4000-8000-000000000004',
    '00000000-0000-4000-8000-000000000003',
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000001',
    'Clean Architecture',
    'Robert C. Martin',
    2017,
    '9780134494166',
    'Practical software architecture principles for maintainable systems.',
    3,
    2,
    0,
    0,
    1,
    'AVAILABLE'
) on conflict (id) do update set
    category_id = excluded.category_id,
    created_by_user_id = excluded.created_by_user_id,
    updated_by_user_id = excluded.updated_by_user_id,
    title = excluded.title,
    author = excluded.author,
    publication_year = excluded.publication_year,
    isbn = excluded.isbn,
    description = excluded.description,
    total_copies = excluded.total_copies,
    available_copies = excluded.available_copies,
    borrowed_copies = excluded.borrowed_copies,
    lost_copies = excluded.lost_copies,
    damaged_copies = excluded.damaged_copies,
    status = excluded.status;

insert into public.borrow_orders (
    id,
    reader_id,
    book_id,
    reviewed_by_user_id,
    status,
    borrow_days,
    requested_at,
    borrowed_at,
    due_at,
    returned_at,
    renewed,
    renewed_at,
    rejection_reason,
    reviewed_at
) values (
    '00000000-0000-4000-8000-000000000005',
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000004',
    '00000000-0000-4000-8000-000000000001',
    'RETURNED',
    14,
    now() - interval '20 days',
    now() - interval '19 days',
    now() - interval '5 days',
    now() - interval '1 day',
    false,
    null,
    null,
    now() - interval '19 days'
) on conflict (id) do update set
    reader_id = excluded.reader_id,
    book_id = excluded.book_id,
    reviewed_by_user_id = excluded.reviewed_by_user_id,
    status = excluded.status,
    borrow_days = excluded.borrow_days,
    requested_at = excluded.requested_at,
    borrowed_at = excluded.borrowed_at,
    due_at = excluded.due_at,
    returned_at = excluded.returned_at,
    renewed = excluded.renewed,
    renewed_at = excluded.renewed_at,
    rejection_reason = excluded.rejection_reason,
    reviewed_at = excluded.reviewed_at;

insert into public.return_requests (
    id,
    borrow_order_id,
    reader_id,
    confirmed_by_user_id,
    status,
    book_condition,
    note,
    requested_at,
    confirmed_at
) values (
    '00000000-0000-4000-8000-000000000006',
    '00000000-0000-4000-8000-000000000005',
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000001',
    'CONFIRMED',
    'DAMAGED',
    'Cover is damaged during return inspection.',
    now() - interval '2 days',
    now() - interval '1 day'
) on conflict (id) do update set
    borrow_order_id = excluded.borrow_order_id,
    reader_id = excluded.reader_id,
    confirmed_by_user_id = excluded.confirmed_by_user_id,
    status = excluded.status,
    book_condition = excluded.book_condition,
    note = excluded.note,
    requested_at = excluded.requested_at,
    confirmed_at = excluded.confirmed_at;

insert into public.fine_levels (
    id,
    created_by_user_id,
    name,
    amount,
    reason_type,
    active
) values (
    '00000000-0000-4000-8000-000000000007',
    '00000000-0000-4000-8000-000000000001',
    'Damaged book',
    50000.00,
    'DAMAGED',
    true
) on conflict (id) do update set
    created_by_user_id = excluded.created_by_user_id,
    name = excluded.name,
    amount = excluded.amount,
    reason_type = excluded.reason_type,
    active = excluded.active;

insert into public.fines (
    id,
    reader_id,
    borrow_order_id,
    return_request_id,
    fine_level_id,
    confirmed_by_user_id,
    amount,
    reason,
    status,
    payment_method,
    paid_at,
    confirmed_at,
    rejection_reason
) values (
    '00000000-0000-4000-8000-000000000008',
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000005',
    '00000000-0000-4000-8000-000000000006',
    '00000000-0000-4000-8000-000000000007',
    null,
    50000.00,
    'Book returned with damaged cover.',
    'UNPAID',
    null,
    null,
    null,
    null
) on conflict (id) do update set
    reader_id = excluded.reader_id,
    borrow_order_id = excluded.borrow_order_id,
    return_request_id = excluded.return_request_id,
    fine_level_id = excluded.fine_level_id,
    confirmed_by_user_id = excluded.confirmed_by_user_id,
    amount = excluded.amount,
    reason = excluded.reason,
    status = excluded.status,
    payment_method = excluded.payment_method,
    paid_at = excluded.paid_at,
    confirmed_at = excluded.confirmed_at,
    rejection_reason = excluded.rejection_reason;

commit;
