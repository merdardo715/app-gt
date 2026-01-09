-- ============================================
-- COMPLETE DATABASE STRUCTURE
-- Sistema di Gestione Cantieri e Lavoratori
-- ============================================

-- ============================================
-- 1. ORGANIZATIONS (Multi-Tenancy)
-- ============================================
CREATE TABLE organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,                          -- Nome azienda
  slug text UNIQUE NOT NULL,                   -- URL-friendly identifier
  owner_id uuid REFERENCES auth.users(id),     -- Proprietario organizzazione
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- ============================================
-- 2. PROFILES (Utenti e Ruoli)
-- ============================================
CREATE TABLE profiles (
  id uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  email text UNIQUE NOT NULL,
  full_name text NOT NULL,
  phone text,
  role text NOT NULL CHECK (role IN ('admin', 'worker', 'org_manager', 'sales_manager', 'administrator')),
  photo_url text,
  position text,                               -- Ruolo lavorativo/titolo
  status text DEFAULT 'active' CHECK (status IN ('active', 'on_break', 'off_site')),
  organization_id uuid REFERENCES organizations(id) ON DELETE CASCADE,
  payment_card_number text,                    -- Numero carta pagamento assegnata
  payment_card_assigned_date date,             -- Data assegnazione carta
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- ============================================
-- 3. WORKSITES (Cantieri)
-- ============================================
CREATE TABLE worksites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  address text NOT NULL,
  latitude numeric,
  longitude numeric,
  created_by uuid REFERENCES profiles(id),
  organization_id uuid REFERENCES organizations(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- ============================================
-- 4. VEHICLES (Veicoli)
-- ============================================
CREATE TABLE vehicles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  plate text NOT NULL,                         -- Targa
  model text DEFAULT '',                       -- Modello
  details text DEFAULT '',                     -- Dettagli veicolo
  kilometers integer DEFAULT 0,                -- Chilometraggio
  inspection_date date,                        -- Data revisione
  issues text DEFAULT '',                      -- Problemi noti
  notes text DEFAULT '',                       -- Note
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(organization_id, plate)
);

-- ============================================
-- 5. VEHICLE_SERVICES (Tagliandi Veicoli)
-- ============================================
CREATE TABLE vehicle_services (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id uuid NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  service_date date NOT NULL,                  -- Data tagliando
  kilometers integer NOT NULL,                 -- Chilometraggio al tagliando
  notes text,
  created_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- ============================================
-- 6. ASSIGNMENTS (Assegnazioni Lavoro)
-- ============================================
CREATE TABLE assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  worker_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  worksite_id uuid NOT NULL REFERENCES worksites(id) ON DELETE CASCADE,
  vehicle_id uuid REFERENCES vehicles(id) ON DELETE SET NULL,
  assigned_date date NOT NULL,
  start_time time,
  end_time time,                               -- Ora fine lavoro
  instructions text,
  confirmed boolean DEFAULT false,
  confirmed_at timestamptz,
  created_by uuid REFERENCES profiles(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- ============================================
-- 7. TIME_ENTRIES (Timbrature)
-- ============================================
CREATE TABLE time_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  worker_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  worksite_id uuid REFERENCES worksites(id) ON DELETE SET NULL,
  entry_type text NOT NULL CHECK (entry_type IN ('work_start', 'lunch_start', 'lunch_end', 'work_end')),
  timestamp timestamptz NOT NULL DEFAULT now(),
  latitude numeric,
  longitude numeric,
  photo_url text,
  notes text,
  edited_by uuid REFERENCES profiles(id),
  edited_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- ============================================
-- 8. DAILY_REPORTS (Rapportini Giornalieri)
-- ============================================
CREATE TABLE daily_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  worker_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  worksite_id uuid NOT NULL REFERENCES worksites(id) ON DELETE CASCADE,
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  report_date date NOT NULL DEFAULT CURRENT_DATE,
  report_time time NOT NULL DEFAULT CURRENT_TIME,
  description text NOT NULL,                   -- Descrizione lavoro
  notes text,
  hours_worked decimal(5,2),                   -- Ore lavorate
  materials_used text,                         -- Materiali usati
  equipment_used text,                         -- Attrezzature usate
  weather_conditions text,                     -- Condizioni meteo
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- ============================================
-- 9. ANNOUNCEMENTS (Comunicazioni)
-- ============================================
CREATE TABLE announcements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  message text NOT NULL,
  priority text NOT NULL DEFAULT 'normal' CHECK (priority IN ('normal', 'important', 'urgent')),
  target_audience text NOT NULL DEFAULT 'all' CHECK (target_audience IN ('all', 'specific')),
  target_worksite_id uuid REFERENCES worksites(id) ON DELETE SET NULL,
  attachment_url text,
  expires_at timestamptz,                      -- Data scadenza comunicazione
  created_by uuid NOT NULL REFERENCES profiles(id),
  organization_id uuid REFERENCES organizations(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- ============================================
-- 10. ANNOUNCEMENT_READS (Letture Comunicazioni)
-- ============================================
CREATE TABLE announcement_reads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  announcement_id uuid NOT NULL REFERENCES announcements(id) ON DELETE CASCADE,
  worker_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  read_at timestamptz DEFAULT now(),
  UNIQUE(announcement_id, worker_id)
);

-- ============================================
-- 11. LEAVE_BALANCES (Monte Ore Permessi)
-- ============================================
CREATE TABLE leave_balances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  worker_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  vacation_hours integer DEFAULT 0 CHECK (vacation_hours >= 0),    -- Ore ferie
  rol_hours integer DEFAULT 0 CHECK (rol_hours >= 0),              -- Ore ROL
  sick_leave_hours integer DEFAULT 0 CHECK (sick_leave_hours >= 0), -- Ore malattia (non si scala)
  organization_id uuid REFERENCES organizations(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(worker_id, organization_id)
);

-- ============================================
-- 12. LEAVE_REQUESTS (Richieste Permessi)
-- ============================================
CREATE TABLE leave_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  worker_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  request_type text NOT NULL CHECK (request_type IN ('vacation', 'rol', 'sick_leave')),
  start_date date,
  end_date date,
  hours_requested integer NOT NULL CHECK (hours_requested > 0),
  reason text,
  certificate_url text,                        -- URL certificato medico (per malattia)
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  organization_id uuid REFERENCES organizations(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- ============================================
-- 13. WORKER_COURSES (Corsi Formazione)
-- ============================================
CREATE TABLE worker_courses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  worker_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  course_name text NOT NULL,
  completion_date date NOT NULL,
  notes text,
  organization_id uuid REFERENCES organizations(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- ============================================
-- 14. WORKER_MEDICAL_CHECKUPS (Visite Mediche)
-- ============================================
CREATE TABLE worker_medical_checkups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  worker_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  checkup_date date NOT NULL,                  -- Data visita
  expiry_date date NOT NULL,                   -- Data scadenza
  notes text,
  organization_id uuid REFERENCES organizations(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- ============================================
-- 15. PAYMENT_CARDS (Carte Carburante/Telepass)
-- ============================================
CREATE TABLE payment_cards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,                          -- Nome carta
  type text NOT NULL CHECK (type IN ('card', 'telepass')),
  info text DEFAULT '',                        -- Informazioni aggiuntive
  organization_id uuid REFERENCES organizations(id) ON DELETE CASCADE NOT NULL,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- ============================================
-- 16. CARD_TRANSACTIONS (Transazioni Carte)
-- ============================================
CREATE TABLE card_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id uuid REFERENCES payment_cards(id) ON DELETE CASCADE NOT NULL,
  amount numeric(10, 2) NOT NULL,
  transaction_date date NOT NULL DEFAULT CURRENT_DATE,
  description text,
  organization_id uuid REFERENCES organizations(id) ON DELETE CASCADE NOT NULL,
  created_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- ============================================
-- 17. CLIENTS (Gestione Clienti)
-- ============================================
CREATE TABLE clients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  status text NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'in_progress', 'completed')),
  notes text,
  issues text,                                 -- Problematiche
  survey_date date,                            -- Data sopralluogo
  start_date date,                             -- Data inizio lavori
  end_date date,                               -- Data fine lavori
  worksite_id uuid REFERENCES worksites(id) ON DELETE SET NULL,
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- ============================================
-- 18. COMPANY_REGULATIONS (Regolamenti Aziendali)
-- ============================================
CREATE TABLE company_regulations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  title text NOT NULL,
  content text NOT NULL DEFAULT '',
  version integer NOT NULL DEFAULT 1,
  is_active boolean NOT NULL DEFAULT true,
  created_by uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ============================================
-- 19. COMPANY_REGULATION_ATTACHMENTS (Allegati Regolamenti)
-- ============================================
CREATE TABLE company_regulation_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  regulation_id uuid NOT NULL REFERENCES company_regulations(id) ON DELETE CASCADE,
  file_name text NOT NULL,
  file_path text NOT NULL,
  file_size bigint NOT NULL,
  mime_type text NOT NULL,
  uploaded_by uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ============================================
-- 20. ISSUED_INVOICES (Fatture Emesse)
-- ============================================
CREATE TABLE issued_invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_number text NOT NULL,
  client_name text NOT NULL,
  amount numeric(12, 2) NOT NULL,
  issue_date date NOT NULL,
  due_date date NOT NULL,
  payment_status text NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'overdue')),
  notes text DEFAULT '',
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ============================================
-- 21. PAYMENT_SCHEDULE (Scadenziario)
-- ============================================
CREATE TABLE payment_schedule (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  type text NOT NULL CHECK (type IN ('bill', 'invoice', 'payment', 'other')),
  amount numeric(12, 2) NOT NULL,
  due_date date NOT NULL,
  payment_status text NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'overdue')),
  notes text DEFAULT '',
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ============================================
-- 22. SUPPLIER_RIBA (RiBa Fornitori)
-- ============================================
CREATE TABLE supplier_riba (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_name text NOT NULL,
  riba_number text NOT NULL,
  amount numeric(12, 2) NOT NULL,
  due_date date NOT NULL,
  payment_status text NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'overdue')),
  notification_sent boolean NOT NULL DEFAULT false,
  notes text DEFAULT '',
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ============================================
-- 23. INVOICE_ADVANCES (Anticipi Fatture)
-- ============================================
CREATE TABLE invoice_advances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_reference text NOT NULL,
  amount numeric(12, 2) NOT NULL,
  advance_date date NOT NULL,
  bank_name text NOT NULL,
  payment_status text NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'received', 'rejected')),
  notes text DEFAULT '',
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ============================================
-- 24. WORKSITE_REVENUES (Ricavi Cantiere)
-- ============================================
CREATE TABLE worksite_revenues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  worksite_id uuid NOT NULL REFERENCES worksites(id) ON DELETE CASCADE,
  amount numeric(12, 2) NOT NULL,
  description text NOT NULL DEFAULT '',
  date date NOT NULL,
  created_by uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ============================================
-- 25. WORKSITE_INVOICES (Fatture Cantiere)
-- ============================================
CREATE TABLE worksite_invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  worksite_id uuid NOT NULL REFERENCES worksites(id) ON DELETE CASCADE,
  amount numeric(12, 2) NOT NULL,
  invoice_number text NOT NULL,
  description text NOT NULL DEFAULT '',
  date date NOT NULL,
  file_path text,                              -- Path file fattura
  file_name text,                              -- Nome file fattura
  created_by uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ============================================
-- 26. WORKSITE_LIQUID_ASSETS (Liquidità Cantiere)
-- ============================================
CREATE TABLE worksite_liquid_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  worksite_id uuid NOT NULL REFERENCES worksites(id) ON DELETE CASCADE,
  amount numeric(12, 2) NOT NULL,
  description text NOT NULL DEFAULT '',
  date date NOT NULL,
  created_by uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ============================================
-- 27. INVOICE_CALCULATIONS (Calcoli Fatture)
-- ============================================
CREATE TABLE invoice_calculations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('income', 'expense', 'estimate')),
  invoice_number text NOT NULL,
  invoice_date date NOT NULL,
  client_name text NOT NULL,
  amount numeric NOT NULL CHECK (amount >= 0),
  created_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- ============================================
-- 28. NOTIFICATION_LOGS (Log Notifiche)
-- ============================================
CREATE TABLE notification_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_type text NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text NOT NULL,
  days_before integer NOT NULL DEFAULT 0,
  sent_at timestamptz NOT NULL DEFAULT now(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(entity_type, entity_id, user_id, days_before)
);

-- ============================================
-- 29. PUSH_NOTIFICATION_TOKENS (Token Push Notifications)
-- ============================================
CREATE TABLE push_notification_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  token text NOT NULL,
  device_type text NOT NULL CHECK (device_type IN ('ios', 'android', 'web')),
  device_name text,
  enabled boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id, token)
);

-- ============================================
-- 30. AUDIT_LOGS (Log Audit)
-- ============================================
CREATE TABLE audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id),
  action text NOT NULL,
  table_name text NOT NULL,
  record_id uuid,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz DEFAULT now()
);

-- ============================================
-- INDEXES
-- ============================================

-- Profiles
CREATE INDEX idx_profiles_organization_id ON profiles(organization_id);

-- Worksites
CREATE INDEX idx_worksites_organization_id ON worksites(organization_id);

-- Vehicles
CREATE INDEX idx_vehicles_organization ON vehicles(organization_id);
CREATE INDEX idx_vehicle_services_vehicle_id ON vehicle_services(vehicle_id);

-- Assignments
CREATE INDEX idx_assignments_worker_id ON assignments(worker_id);
CREATE INDEX idx_assignments_date ON assignments(assigned_date);
CREATE INDEX idx_assignments_vehicle ON assignments(vehicle_id);

-- Time Entries
CREATE INDEX idx_time_entries_worker_id ON time_entries(worker_id);
CREATE INDEX idx_time_entries_timestamp ON time_entries(timestamp);

-- Daily Reports
CREATE INDEX idx_daily_reports_worker_id ON daily_reports(worker_id);
CREATE INDEX idx_daily_reports_worksite_id ON daily_reports(worksite_id);
CREATE INDEX idx_daily_reports_report_date ON daily_reports(report_date);
CREATE INDEX idx_daily_reports_organization_id ON daily_reports(organization_id);

-- Announcements
CREATE INDEX idx_announcements_created_at ON announcements(created_at);
CREATE INDEX idx_announcements_organization_id ON announcements(organization_id);
CREATE INDEX idx_announcement_reads_worker_id ON announcement_reads(worker_id);

-- Leave Management
CREATE INDEX idx_leave_balances_worker ON leave_balances(worker_id);
CREATE INDEX idx_leave_balances_org ON leave_balances(organization_id);
CREATE INDEX idx_leave_requests_worker ON leave_requests(worker_id);
CREATE INDEX idx_leave_requests_org ON leave_requests(organization_id);
CREATE INDEX idx_leave_requests_status ON leave_requests(status);

-- Worker Details
CREATE INDEX idx_worker_courses_worker ON worker_courses(worker_id);
CREATE INDEX idx_worker_courses_org ON worker_courses(organization_id);
CREATE INDEX idx_worker_medical_worker ON worker_medical_checkups(worker_id);
CREATE INDEX idx_worker_medical_org ON worker_medical_checkups(organization_id);
CREATE INDEX idx_worker_medical_expiry ON worker_medical_checkups(expiry_date);

-- Payment Cards
CREATE INDEX idx_payment_cards_org ON payment_cards(organization_id);
CREATE INDEX idx_card_transactions_card ON card_transactions(card_id);
CREATE INDEX idx_card_transactions_org ON card_transactions(organization_id);
CREATE INDEX idx_card_transactions_date ON card_transactions(transaction_date);

-- Clients
CREATE INDEX idx_clients_org ON clients(organization_id);
CREATE INDEX idx_clients_status ON clients(status);
CREATE INDEX idx_clients_worksite ON clients(worksite_id);

-- Company Regulations
CREATE INDEX idx_regulations_org ON company_regulations(organization_id);
CREATE INDEX idx_regulation_attachments_reg ON company_regulation_attachments(regulation_id);

-- Accounting
CREATE INDEX idx_invoices_org ON issued_invoices(organization_id);
CREATE INDEX idx_invoices_due ON issued_invoices(due_date);
CREATE INDEX idx_schedule_org ON payment_schedule(organization_id);
CREATE INDEX idx_schedule_due ON payment_schedule(due_date);
CREATE INDEX idx_riba_org ON supplier_riba(organization_id);
CREATE INDEX idx_riba_due ON supplier_riba(due_date);
CREATE INDEX idx_advances_org ON invoice_advances(organization_id);

-- Worksite Financials
CREATE INDEX idx_worksite_revenues_worksite ON worksite_revenues(worksite_id);
CREATE INDEX idx_worksite_revenues_date ON worksite_revenues(worksite_id, date DESC);
CREATE INDEX idx_worksite_revenues_org ON worksite_revenues(organization_id);
CREATE INDEX idx_worksite_invoices_worksite ON worksite_invoices(worksite_id);
CREATE INDEX idx_worksite_invoices_date ON worksite_invoices(worksite_id, date DESC);
CREATE INDEX idx_worksite_invoices_org ON worksite_invoices(organization_id);
CREATE INDEX idx_worksite_liquid_assets_worksite ON worksite_liquid_assets(worksite_id);
CREATE INDEX idx_worksite_liquid_assets_date ON worksite_liquid_assets(worksite_id, date DESC);
CREATE INDEX idx_worksite_liquid_assets_org ON worksite_liquid_assets(organization_id);

-- Invoice Calculations
CREATE INDEX idx_invoice_calculations_org_type ON invoice_calculations(organization_id, type);
CREATE INDEX idx_invoice_calculations_date ON invoice_calculations(invoice_date DESC);

-- Notifications
CREATE INDEX idx_notification_logs_user ON notification_logs(user_id, sent_at DESC);
CREATE INDEX idx_notification_logs_entity ON notification_logs(entity_type, entity_id);
CREATE INDEX idx_notification_logs_org ON notification_logs(organization_id);
CREATE INDEX idx_push_tokens_user_id ON push_notification_tokens(user_id);
CREATE INDEX idx_push_tokens_enabled ON push_notification_tokens(enabled);

-- ============================================
-- STORAGE BUCKETS
-- ============================================
-- leave-certificates (Certificati medici)
-- regulation-files (File regolamenti)
-- worksite-invoices (Fatture cantieri)

-- ============================================
-- RUOLI UTENTE
-- ============================================
-- admin: Amministratore generale del sistema
-- worker: Lavoratore/Operaio
-- org_manager: Manager organizzazione (accesso gestionale cantieri)
-- sales_manager: Manager commerciale (accesso gestione clienti)
-- administrator: Amministratore organizzazione (accesso totale)

-- ============================================
-- FUNZIONI E TRIGGER PRINCIPALI
-- ============================================
-- update_updated_at_column(): Aggiorna automaticamente il campo updated_at
-- update_leave_balance_on_approval(): Scala le ore quando un permesso viene approvato
-- get_user_organization_id(): Ottiene l'organization_id dell'utente corrente
