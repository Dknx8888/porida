--
-- PostgreSQL database dump
--

\restrict AtWweLLC9aWCcUAbQHpueagDgNzwowPPawIdmT7qdi6xqBv1c7HpMGxdWI3J2al

-- Dumped from database version 18.6 (Ubuntu 18.6-0ubuntu0.26.04.1)
-- Dumped by pg_dump version 18.6 (Ubuntu 18.6-0ubuntu0.26.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: daily_price; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.daily_price (
    security_id uuid NOT NULL,
    date date NOT NULL,
    close numeric(20,8) NOT NULL,
    adjusted_close numeric(20,8) NOT NULL,
    CONSTRAINT daily_price_adjusted_close_positive CHECK ((adjusted_close > (0)::numeric)),
    CONSTRAINT daily_price_close_positive CHECK ((close > (0)::numeric))
);


--
-- Name: holding; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.holding (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    portfolio_id uuid NOT NULL,
    security_id uuid NOT NULL,
    shares numeric(20,8) NOT NULL,
    CONSTRAINT holding_shares_positive CHECK ((shares > (0)::numeric))
);


--
-- Name: portfolio; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.portfolio (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT portfolio_name_not_blank CHECK ((btrim(name) <> ''::text))
);


--
-- Name: security; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.security (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ticker text NOT NULL,
    name text NOT NULL,
    sector text,
    currency text NOT NULL,
    is_etf boolean NOT NULL,
    CONSTRAINT security_currency_usd CHECK ((currency = 'USD'::text)),
    CONSTRAINT security_name_not_blank CHECK ((btrim(name) <> ''::text)),
    CONSTRAINT security_sector_not_blank CHECK (((sector IS NULL) OR (btrim(sector) <> ''::text))),
    CONSTRAINT security_ticker_normalized CHECK (((ticker <> ''::text) AND (ticker = upper(btrim(ticker)))))
);


--
-- Name: COLUMN security.currency; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.security.currency IS 'Currently only USD';


--
-- Name: daily_price pk_daily_price; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_price
    ADD CONSTRAINT pk_daily_price PRIMARY KEY (security_id, date);


--
-- Name: holding pk_holding; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.holding
    ADD CONSTRAINT pk_holding PRIMARY KEY (id);


--
-- Name: portfolio pk_portfolio; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.portfolio
    ADD CONSTRAINT pk_portfolio PRIMARY KEY (id);


--
-- Name: security pk_securit; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.security
    ADD CONSTRAINT pk_securit PRIMARY KEY (id);


--
-- Name: holding uq_holding_portfolio_security; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.holding
    ADD CONSTRAINT uq_holding_portfolio_security UNIQUE (portfolio_id, security_id);


--
-- Name: security uq_security_ticker; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.security
    ADD CONSTRAINT uq_security_ticker UNIQUE (ticker);


--
-- Name: daily_price fk_daily_price_security; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_price
    ADD CONSTRAINT fk_daily_price_security FOREIGN KEY (security_id) REFERENCES public.security(id) ON DELETE CASCADE;


--
-- Name: holding fk_holding_portfolio; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.holding
    ADD CONSTRAINT fk_holding_portfolio FOREIGN KEY (portfolio_id) REFERENCES public.portfolio(id) ON DELETE CASCADE;


--
-- Name: holding fk_holding_security; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.holding
    ADD CONSTRAINT fk_holding_security FOREIGN KEY (security_id) REFERENCES public.security(id);


--
-- PostgreSQL database dump complete
--

\unrestrict AtWweLLC9aWCcUAbQHpueagDgNzwowPPawIdmT7qdi6xqBv1c7HpMGxdWI3J2al

