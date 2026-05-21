-- Agent RLS Policies
-- Agents can read all data across every landlord/tenant/contractor,
-- giving them full visibility into the platform like the CGE agent portal.

-- Helper: reusable inline check so we don't need a separate function
-- (avoids recursion — we read profiles directly with auth.uid())

-- profiles: agents can read every profile
CREATE POLICY "agents read all profiles"
  ON public.profiles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'agent'
    )
  );

-- tenancies: agents can read all tenancies across all landlords
CREATE POLICY "agents read all tenancies"
  ON public.tenancies FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'agent'
    )
  );

-- incidents: agents can read all maintenance incidents
CREATE POLICY "agents read all incidents"
  ON public.incidents FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'agent'
    )
  );

-- compliance_docs: agents can read all compliance documents
CREATE POLICY "agents read all compliance docs"
  ON public.compliance_docs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'agent'
    )
  );

-- contractor_details: agents can read all contractor profiles
CREATE POLICY "agents read all contractor details"
  ON public.contractor_details FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'agent'
    )
  );
