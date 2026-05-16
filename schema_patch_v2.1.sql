-- ============================================================
-- PATCH v2.1 — Tesserato.club
-- Data: 17/05/2026
-- Applicare DOPO lo schema principale
-- ============================================================

-- ── Tabelle nuove ────────────────────────────────────────────
-- Collega profilo utente a record atleta (per maggiorenni)
CREATE TABLE IF NOT EXISTS profilo_atleta (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profilo_id uuid REFERENCES profilo(id) ON DELETE CASCADE UNIQUE,
  atleta_id  uuid REFERENCES atleta(id)  ON DELETE CASCADE,
  UNIQUE(profilo_id, atleta_id)
);
ALTER TABLE profilo_atleta ENABLE ROW LEVEL SECURITY;
CREATE POLICY "auth_profilo_atleta" ON profilo_atleta
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Palestre / impianti
CREATE TABLE IF NOT EXISTS palestra (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  societa_id uuid REFERENCES societa(id) ON DELETE CASCADE,
  nome       text NOT NULL,
  indirizzo  text,
  comune     text,
  capienza   int,
  note       text,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE palestra ENABLE ROW LEVEL SECURITY;
CREATE POLICY "autenticati_palestra" ON palestra
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Calendario allenamenti
CREATE TABLE IF NOT EXISTS allenamento (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  gruppo_id        uuid REFERENCES gruppo(id) ON DELETE CASCADE,
  palestra_id      uuid REFERENCES palestra(id) ON DELETE SET NULL,
  stagione_id      uuid REFERENCES stagione(id) ON DELETE CASCADE,
  giorno_settimana int NOT NULL CHECK (giorno_settimana BETWEEN 1 AND 7),
  ora_inizio       time NOT NULL,
  ora_fine         time NOT NULL,
  note             text
);
ALTER TABLE allenamento ENABLE ROW LEVEL SECURITY;
CREATE POLICY "autenticati_allenamento" ON allenamento
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Presenze
CREATE TABLE IF NOT EXISTS presenza (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  allenamento_id uuid REFERENCES allenamento(id) ON DELETE CASCADE,
  atleta_id      uuid REFERENCES atleta(id)       ON DELETE CASCADE,
  data           date NOT NULL,
  presente       boolean DEFAULT false,
  note           text,
  registrato_da  uuid REFERENCES profilo(id),
  created_at     timestamptz DEFAULT now(),
  UNIQUE(allenamento_id, atleta_id, data)
);
ALTER TABLE presenza ENABLE ROW LEVEL SECURITY;
CREATE POLICY "autenticati_presenza" ON presenza
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ── Colonne aggiunte a tabelle esistenti ─────────────────────

-- Stagione: colonna note
ALTER TABLE stagione ADD COLUMN IF NOT EXISTS note text;

-- Pagamento: colonne per gestione bonifico e verifica
ALTER TABLE pagamento ADD COLUMN IF NOT EXISTS contabile_url       text;
ALTER TABLE pagamento ADD COLUMN IF NOT EXISTS richiesta_verifica  boolean DEFAULT false;
ALTER TABLE pagamento ADD COLUMN IF NOT EXISTS data_richiesta      timestamptz;
ALTER TABLE pagamento ADD COLUMN IF NOT EXISTS pagato_il           date;

-- ── Fix RLS su tabelle esistenti ─────────────────────────────

-- iscrizione: rimuovi policy restrittiva che bloccava genitore/atleta
DROP POLICY IF EXISTS iscrizione_select ON iscrizione;

-- pagamento: aggiungi lettura per tutti gli autenticati
DROP POLICY IF EXISTS pagamento_select ON pagamento;
CREATE POLICY "read_pagamento_authenticated" ON pagamento
  FOR SELECT TO authenticated USING (true);

-- pagamento: permetti al genitore/atleta di allegare contabile
CREATE POLICY "genitore_update_bonifico" ON pagamento
  FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (
    richiesta_verifica = true AND
    pagato = false
  );

-- ── Ruolo atleta ─────────────────────────────────────────────
-- Aggiorna constraint ruolo profilo per includere 'atleta'
ALTER TABLE profilo DROP CONSTRAINT IF EXISTS profilo_ruolo_check;
ALTER TABLE profilo ADD CONSTRAINT profilo_ruolo_check
  CHECK (ruolo IN ('amministratore','segreteria','allenatore','genitore','atleta'));

-- ── Storage bucket contabili ──────────────────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('contabili', 'contabili', false)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "upload_contabili" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'contabili');

CREATE POLICY "read_contabili" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'contabili');

-- ============================================================
-- Fine patch v2.1
-- ============================================================
