-- Allow buyers to attach selected courier/shipping info to their own pending orders
CREATE POLICY "Users can update own pending orders"
ON public.orders
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id AND status = 'pending')
WITH CHECK (auth.uid() = user_id);
