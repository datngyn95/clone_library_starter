-- Supabase/PostgreSQL schema for the library management project.
-- Authentication is implemented by the application using public.users.email
-- and public.users.password_hash. This script does not use Supabase Auth.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create table if not exists public.users (
    id uuid primary key default gen_random_uuid(),
    email varchar(255) not null unique,
    password_hash text not null,
    full_name varchar(50) not null,
    phone varchar(20),
    address varchar(255),
    role varchar(20) not null default 'READER',
    status varchar(30) not null default 'PENDING_VERIFICATION',
    email_verified_at timestamptz,
    joined_at timestamptz not null default now(),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint users_role_check
        check (role in ('READER', 'LIBRARIAN', 'ADMIN')),
    constraint users_status_check
        check (status in ('PENDING_VERIFICATION', 'ACTIVE', 'DISABLED')),
    constraint users_email_format_check
        check (email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'),
    constraint users_full_name_length_check
        check (char_length(full_name) between 1 and 50),
    constraint users_address_length_check
        check (address is null or char_length(address) <= 255)
);

create table if not exists public.email_verification_tokens (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    token_hash text not null unique,
    expires_at timestamptz not null,
    used_at timestamptz,
    created_at timestamptz not null default now()
);

create table if not exists public.categories (
    id uuid primary key default gen_random_uuid(),
    name varchar(50) not null unique,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint categories_name_length_check
        check (char_length(name) between 1 and 50)
);

create table if not exists public.books (
    id uuid primary key default gen_random_uuid(),
    category_id uuid not null references public.categories(id) on delete restrict,
    created_by_user_id uuid references public.users(id) on delete set null,
    updated_by_user_id uuid references public.users(id) on delete set null,
    title varchar(100) not null,
    author varchar(100) not null,
    publication_year integer not null,
    isbn varchar(17) unique,
    description varchar(255) not null,
    total_copies integer not null,
    available_copies integer not null,
    borrowed_copies integer not null default 0,
    lost_copies integer not null default 0,
    damaged_copies integer not null default 0,
    status varchar(20) not null default 'AVAILABLE',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint books_title_length_check
        check (char_length(title) between 1 and 100),
    constraint books_author_length_check
        check (char_length(author) between 1 and 100),
    constraint books_publication_year_check
        check (publication_year between 1900 and extract(year from now())::integer),
    constraint books_isbn_format_check
        check (isbn is null or isbn ~ '^(?:[0-9]{9}[0-9Xx]|[0-9]{13})$'),
    constraint books_description_length_check
        check (char_length(description) between 1 and 255),
    constraint books_copy_count_check
        check (
            total_copies > 0
            and available_copies >= 0
            and borrowed_copies >= 0
            and lost_copies >= 0
            and damaged_copies >= 0
            and available_copies + borrowed_copies + lost_copies + damaged_copies <= total_copies
        ),
    constraint books_status_check
        check (status in ('AVAILABLE', 'UNAVAILABLE'))
);

create table if not exists public.borrow_orders (
    id uuid primary key default gen_random_uuid(),
    reader_id uuid not null references public.users(id) on delete restrict,
    book_id uuid not null references public.books(id) on delete restrict,
    reviewed_by_user_id uuid references public.users(id) on delete set null,
    status varchar(20) not null default 'PENDING',
    borrow_days integer not null,
    requested_at timestamptz not null default now(),
    borrowed_at timestamptz,
    due_at timestamptz,
    returned_at timestamptz,
    renewed boolean not null default false,
    renewed_at timestamptz,
    rejection_reason text,
    reviewed_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint borrow_orders_status_check
        check (status in ('PENDING', 'BORROWED', 'OVERDUE', 'RETURNED', 'REJECTED')),
    constraint borrow_orders_borrow_days_check
        check (borrow_days between 1 and 30),
    constraint borrow_orders_rejection_reason_check
        check (status <> 'REJECTED' or nullif(trim(rejection_reason), '') is not null)
);

create table if not exists public.return_requests (
    id uuid primary key default gen_random_uuid(),
    borrow_order_id uuid not null references public.borrow_orders(id) on delete cascade,
    reader_id uuid not null references public.users(id) on delete restrict,
    confirmed_by_user_id uuid references public.users(id) on delete set null,
    status varchar(20) not null default 'PENDING',
    book_condition varchar(20),
    note varchar(500),
    requested_at timestamptz not null default now(),
    confirmed_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint return_requests_status_check
        check (status in ('PENDING', 'CONFIRMED', 'REJECTED')),
    constraint return_requests_book_condition_check
        check (book_condition is null or book_condition in ('NORMAL', 'DAMAGED', 'LOST')),
    constraint return_requests_note_length_check
        check (note is null or char_length(note) <= 500),
    constraint return_requests_condition_required_check
        check (status <> 'CONFIRMED' or book_condition is not null),
    constraint return_requests_note_required_for_problem_check
        check (book_condition not in ('DAMAGED', 'LOST') or nullif(trim(note), '') is not null)
);

create unique index if not exists return_requests_one_pending_per_borrow_order
    on public.return_requests (borrow_order_id)
    where status = 'PENDING';

create table if not exists public.fine_levels (
    id uuid primary key default gen_random_uuid(),
    created_by_user_id uuid references public.users(id) on delete set null,
    name varchar(25) not null unique,
    amount numeric(12, 2) not null,
    reason_type varchar(20) not null,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint fine_levels_name_length_check
        check (char_length(name) between 1 and 25),
    constraint fine_levels_amount_check
        check (amount > 0),
    constraint fine_levels_reason_type_check
        check (reason_type in ('OVERDUE', 'DAMAGED', 'LOST', 'OTHER'))
);

create table if not exists public.fines (
    id uuid primary key default gen_random_uuid(),
    reader_id uuid not null references public.users(id) on delete restrict,
    borrow_order_id uuid references public.borrow_orders(id) on delete set null,
    return_request_id uuid references public.return_requests(id) on delete set null,
    fine_level_id uuid references public.fine_levels(id) on delete set null,
    confirmed_by_user_id uuid references public.users(id) on delete set null,
    amount numeric(12, 2) not null,
    reason text not null,
    status varchar(30) not null default 'UNPAID',
    payment_method varchar(30),
    paid_at timestamptz,
    confirmed_at timestamptz,
    rejection_reason text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint fines_amount_check
        check (amount > 0),
    constraint fines_reason_check
        check (nullif(trim(reason), '') is not null),
    constraint fines_status_check
        check (status in ('UNPAID', 'PENDING_CONFIRMATION', 'PAID', 'REJECTED')),
    constraint fines_payment_method_check
        check (payment_method is null or payment_method in ('BANK_TRANSFER')),
    constraint fines_rejection_reason_check
        check (status <> 'REJECTED' or nullif(trim(rejection_reason), '') is not null)
);

create index if not exists email_verification_tokens_user_id_idx
    on public.email_verification_tokens (user_id);
create index if not exists books_category_id_idx
    on public.books (category_id);
create index if not exists books_title_author_idx
    on public.books (title, author);
create index if not exists borrow_orders_reader_id_idx
    on public.borrow_orders (reader_id);
create index if not exists borrow_orders_book_id_idx
    on public.borrow_orders (book_id);
create index if not exists borrow_orders_status_idx
    on public.borrow_orders (status);
create index if not exists return_requests_status_idx
    on public.return_requests (status);
create index if not exists fines_reader_id_idx
    on public.fines (reader_id);
create index if not exists fines_status_idx
    on public.fines (status);

drop trigger if exists set_users_updated_at on public.users;
create trigger set_users_updated_at
before update on public.users
for each row execute function public.set_updated_at();

drop trigger if exists set_categories_updated_at on public.categories;
create trigger set_categories_updated_at
before update on public.categories
for each row execute function public.set_updated_at();

drop trigger if exists set_books_updated_at on public.books;
create trigger set_books_updated_at
before update on public.books
for each row execute function public.set_updated_at();

drop trigger if exists set_borrow_orders_updated_at on public.borrow_orders;
create trigger set_borrow_orders_updated_at
before update on public.borrow_orders
for each row execute function public.set_updated_at();

drop trigger if exists set_return_requests_updated_at on public.return_requests;
create trigger set_return_requests_updated_at
before update on public.return_requests
for each row execute function public.set_updated_at();

drop trigger if exists set_fine_levels_updated_at on public.fine_levels;
create trigger set_fine_levels_updated_at
before update on public.fine_levels
for each row execute function public.set_updated_at();

drop trigger if exists set_fines_updated_at on public.fines;
create trigger set_fines_updated_at
before update on public.fines
for each row execute function public.set_updated_at();
