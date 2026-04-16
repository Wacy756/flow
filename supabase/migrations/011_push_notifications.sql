-- ============================================================
-- Migration 011: FCM Push Notifications
-- ============================================================
-- Stores FCM device tokens and per-user notification preferences.
-- A trigger on the notifications table fires an Edge Function via
-- pg_net to deliver OS-level pushes to all registered devices.
--
-- SETUP REQUIRED after applying this migration:
--   1. Deploy the Edge Function:
--        supabase functions deploy send-push
--   2. Set your project URL in the database (run in SQL editor):
--        ALTER DATABASE postgres
--          SET app.supabase_project_url = 'https://YOUR_PROJECT_REF.supabase.co';
--   3. Set your service-role key:
--        ALTER DATABASE postgres
--          SET app.supabase_service_role_key = 'YOUR_SERVICE_ROLE_KEY';
--   4. Enable pg_net if not already enabled:
--        CREATE EXTENSION IF NOT EXISTS pg_net;
-- ============================================================

-- 1. FCM device token registry
-- ============================================================
CREATE TABLE IF NOT EXISTS public.fcm_tokens (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  token      TEXT        NOT NULL,
  platform   TEXT        NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, token)
);

ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Users can manage their own device tokens
CREATE POLICY "Users manage own FCM tokens"
  ON public.fcm_tokens
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE INDEX IF NOT EXISTS fcm_tokens_user_id_idx ON public.fcm_tokens (user_id);

-- 2. Per-user notification preferences
-- ============================================================
CREATE TABLE IF NOT EXISTS public.notification_preferences (
  user_id           UUID    PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  push_enabled      BOOLEAN NOT NULL DEFAULT TRUE,
  push_maintenance  BOOLEAN NOT NULL DEFAULT TRUE,
  push_rent         BOOLEAN NOT NULL DEFAULT TRUE,
  push_compliance   BOOLEAN NOT NULL DEFAULT TRUE,
  push_applications BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own notification preferences"
  ON public.notification_preferences
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- 3. Trigger: send push notification on every new in-app notification
-- ============================================================
-- Maps notification type → preference column so the Edge Function
-- can honour per-type opt-outs.

CREATE OR REPLACE FUNCTION public.send_push_on_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_url  TEXT;
  v_key  TEXT;
BEGIN
  -- Read project URL + key from database settings (set during setup)
  v_url := current_setting('app.supabase_project_url', true);
  v_key := current_setting('app.supabase_service_role_key', true);

  -- Skip if settings not configured yet
  IF v_url IS NULL OR v_url = '' THEN
    RETURN NEW;
  END IF;

  -- Fire-and-forget HTTP POST to the Edge Function
  PERFORM net.http_post(
    url     := v_url || '/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_key
    ),
    body    := jsonb_build_object(
      'user_id', NEW.user_id,
      'type',    NEW.type,
      'title',   NEW.title,
      'body',    NEW.body,
      'data',    NEW.data
    )::text
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_send_push ON public.notifications;
CREATE TRIGGER trg_send_push
  AFTER INSERT ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.send_push_on_notification();
