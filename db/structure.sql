SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: prevent_system_tag_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_system_tag_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'system tags cannot be updated or deleted';
END;
$$;


--
-- Name: prevent_tag_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_tag_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'tags must be deactivated instead of deleted';
END;
$$;


--
-- Name: prevent_task_tag_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_task_tag_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'task tags must be deactivated instead of deleted';
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: recurrence_rule_dates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recurrence_rule_dates (
    id bigint NOT NULL,
    recurrence_rule_id bigint NOT NULL,
    run_date date NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: recurrence_rule_dates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.recurrence_rule_dates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: recurrence_rule_dates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.recurrence_rule_dates_id_seq OWNED BY public.recurrence_rule_dates.id;


--
-- Name: recurrence_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recurrence_rules (
    id bigint NOT NULL,
    task_id bigint NOT NULL,
    rule_type character varying NOT NULL,
    interval_value integer,
    day_of_month integer,
    day_of_month_parity character varying,
    month_of_year integer,
    weekday integer,
    weekday_parity character varying,
    execution_time time without time zone NOT NULL,
    timezone character varying NOT NULL,
    date_start date NOT NULL,
    date_end date,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: recurrence_rules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.recurrence_rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: recurrence_rules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.recurrence_rules_id_seq OWNED BY public.recurrence_rules.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags (
    id bigint NOT NULL,
    name character varying NOT NULL,
    description text,
    is_system_tag boolean DEFAULT false NOT NULL,
    deactivated_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tags_id_seq OWNED BY public.tags.id;


--
-- Name: task_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_events (
    id bigint NOT NULL,
    task_id bigint NOT NULL,
    occurrence_id bigint,
    event_type character varying NOT NULL,
    actor_id bigint NOT NULL,
    occurred_at timestamp(6) without time zone NOT NULL,
    payload_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: task_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.task_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: task_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.task_events_id_seq OWNED BY public.task_events.id;


--
-- Name: task_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_occurrences (
    id bigint NOT NULL,
    task_id bigint NOT NULL,
    scheduled_at timestamp(6) without time zone NOT NULL,
    status character varying NOT NULL,
    actual_at timestamp(6) without time zone,
    postponed_to timestamp(6) without time zone,
    skip_reason character varying,
    generated_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: task_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.task_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: task_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.task_occurrences_id_seq OWNED BY public.task_occurrences.id;


--
-- Name: task_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_tags (
    id bigint NOT NULL,
    task_id bigint NOT NULL,
    tag_id bigint NOT NULL,
    deactivated_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: task_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.task_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: task_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.task_tags_id_seq OWNED BY public.task_tags.id;


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tasks (
    id bigint NOT NULL,
    parent_task_id bigint,
    root_task_id bigint,
    task_kind character varying NOT NULL,
    status character varying NOT NULL,
    end_reason character varying,
    name character varying NOT NULL,
    description text,
    responsible_id bigint,
    first_run_at timestamp(6) without time zone,
    next_run_at timestamp(6) without time zone,
    completed_at timestamp(6) without time zone,
    cancelled_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    completion_date date,
    creator_id bigint,
    delegated_user_id bigint,
    accepted_at timestamp(6) without time zone,
    cancellation_reason character varying,
    deactivated_at timestamp(6) without time zone,
    CONSTRAINT tasks_have_owner_context CHECK (((creator_id IS NOT NULL) OR (responsible_id IS NOT NULL) OR (delegated_user_id IS NOT NULL)))
);


--
-- Name: tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tasks_id_seq OWNED BY public.tasks.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email character varying NOT NULL,
    password_digest character varying NOT NULL,
    password_salt character varying NOT NULL,
    role character varying NOT NULL,
    name character varying NOT NULL,
    last_name character varying NOT NULL,
    auth_token_digest character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: recurrence_rule_dates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurrence_rule_dates ALTER COLUMN id SET DEFAULT nextval('public.recurrence_rule_dates_id_seq'::regclass);


--
-- Name: recurrence_rules id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurrence_rules ALTER COLUMN id SET DEFAULT nextval('public.recurrence_rules_id_seq'::regclass);


--
-- Name: tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags ALTER COLUMN id SET DEFAULT nextval('public.tags_id_seq'::regclass);


--
-- Name: task_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_events ALTER COLUMN id SET DEFAULT nextval('public.task_events_id_seq'::regclass);


--
-- Name: task_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_occurrences ALTER COLUMN id SET DEFAULT nextval('public.task_occurrences_id_seq'::regclass);


--
-- Name: task_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_tags ALTER COLUMN id SET DEFAULT nextval('public.task_tags_id_seq'::regclass);


--
-- Name: tasks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks ALTER COLUMN id SET DEFAULT nextval('public.tasks_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: recurrence_rule_dates recurrence_rule_dates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurrence_rule_dates
    ADD CONSTRAINT recurrence_rule_dates_pkey PRIMARY KEY (id);


--
-- Name: recurrence_rules recurrence_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurrence_rules
    ADD CONSTRAINT recurrence_rules_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: task_events task_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_events
    ADD CONSTRAINT task_events_pkey PRIMARY KEY (id);


--
-- Name: task_occurrences task_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_occurrences
    ADD CONSTRAINT task_occurrences_pkey PRIMARY KEY (id);


--
-- Name: task_tags task_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_tags
    ADD CONSTRAINT task_tags_pkey PRIMARY KEY (id);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_recurrence_rule_dates_on_recurrence_rule_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recurrence_rule_dates_on_recurrence_rule_id ON public.recurrence_rule_dates USING btree (recurrence_rule_id);


--
-- Name: index_recurrence_rule_dates_on_rule_and_run_date; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_recurrence_rule_dates_on_rule_and_run_date ON public.recurrence_rule_dates USING btree (recurrence_rule_id, run_date);


--
-- Name: index_recurrence_rules_on_rule_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recurrence_rules_on_rule_type ON public.recurrence_rules USING btree (rule_type);


--
-- Name: index_recurrence_rules_on_task_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_recurrence_rules_on_task_id ON public.recurrence_rules USING btree (task_id);


--
-- Name: index_task_events_on_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_task_events_on_actor_id ON public.task_events USING btree (actor_id);


--
-- Name: index_task_events_on_event_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_task_events_on_event_type ON public.task_events USING btree (event_type);


--
-- Name: index_task_events_on_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_task_events_on_occurred_at ON public.task_events USING btree (occurred_at);


--
-- Name: index_task_events_on_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_task_events_on_occurrence_id ON public.task_events USING btree (occurrence_id);


--
-- Name: index_task_events_on_task_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_task_events_on_task_id ON public.task_events USING btree (task_id);


--
-- Name: index_task_occurrences_on_task_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_task_occurrences_on_task_id ON public.task_occurrences USING btree (task_id);


--
-- Name: index_task_occurrences_on_task_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_task_occurrences_on_task_id_and_status ON public.task_occurrences USING btree (task_id, status);


--
-- Name: index_task_occurrences_on_task_id_when_current; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_task_occurrences_on_task_id_when_current ON public.task_occurrences USING btree (task_id) WHERE ((status)::text = ANY ((ARRAY['planned'::character varying, 'postponed'::character varying])::text[]));


--
-- Name: index_task_tags_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_task_tags_on_tag_id ON public.task_tags USING btree (tag_id);


--
-- Name: index_task_tags_on_task_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_task_tags_on_task_id ON public.task_tags USING btree (task_id);


--
-- Name: index_task_tags_on_task_id_and_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_task_tags_on_task_id_and_tag_id ON public.task_tags USING btree (task_id, tag_id);


--
-- Name: index_tasks_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_creator_id ON public.tasks USING btree (creator_id);


--
-- Name: index_tasks_on_delegated_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_delegated_user_id ON public.tasks USING btree (delegated_user_id);


--
-- Name: index_tasks_on_next_run_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_next_run_at ON public.tasks USING btree (next_run_at);


--
-- Name: index_tasks_on_parent_task_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_parent_task_id ON public.tasks USING btree (parent_task_id);


--
-- Name: index_tasks_on_responsible_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_responsible_id ON public.tasks USING btree (responsible_id);


--
-- Name: index_tasks_on_root_task_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_root_task_id ON public.tasks USING btree (root_task_id);


--
-- Name: index_tasks_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_status ON public.tasks USING btree (status);


--
-- Name: index_tasks_on_task_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_task_kind ON public.tasks USING btree (task_kind);


--
-- Name: index_users_on_auth_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_auth_token_digest ON public.users USING btree (auth_token_digest);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_name_and_last_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_name_and_last_name ON public.users USING btree (name, last_name);


--
-- Name: tags prevent_system_tag_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER prevent_system_tag_mutation BEFORE UPDATE ON public.tags FOR EACH ROW WHEN (old.is_system_tag) EXECUTE FUNCTION public.prevent_system_tag_mutation();


--
-- Name: tags prevent_tag_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER prevent_tag_delete BEFORE DELETE ON public.tags FOR EACH ROW EXECUTE FUNCTION public.prevent_tag_delete();


--
-- Name: tags prevent_tag_truncate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER prevent_tag_truncate BEFORE TRUNCATE ON public.tags FOR EACH STATEMENT EXECUTE FUNCTION public.prevent_tag_delete();


--
-- Name: task_tags prevent_task_tag_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER prevent_task_tag_delete BEFORE DELETE ON public.task_tags FOR EACH ROW EXECUTE FUNCTION public.prevent_task_tag_delete();


--
-- Name: task_tags prevent_task_tag_truncate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER prevent_task_tag_truncate BEFORE TRUNCATE ON public.task_tags FOR EACH STATEMENT EXECUTE FUNCTION public.prevent_task_tag_delete();


--
-- Name: tasks fk_rails_00f6e5b7b4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_rails_00f6e5b7b4 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: tasks fk_rails_21c0bd1362; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_rails_21c0bd1362 FOREIGN KEY (root_task_id) REFERENCES public.tasks(id);


--
-- Name: task_tags fk_rails_2a907ecb20; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_tags
    ADD CONSTRAINT fk_rails_2a907ecb20 FOREIGN KEY (task_id) REFERENCES public.tasks(id);


--
-- Name: recurrence_rule_dates fk_rails_68b858cb8f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurrence_rule_dates
    ADD CONSTRAINT fk_rails_68b858cb8f FOREIGN KEY (recurrence_rule_id) REFERENCES public.recurrence_rules(id);


--
-- Name: task_events fk_rails_6a7593e924; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_events
    ADD CONSTRAINT fk_rails_6a7593e924 FOREIGN KEY (occurrence_id) REFERENCES public.task_occurrences(id);


--
-- Name: task_events fk_rails_763c41facb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_events
    ADD CONSTRAINT fk_rails_763c41facb FOREIGN KEY (task_id) REFERENCES public.tasks(id);


--
-- Name: tasks fk_rails_82e1714c60; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_rails_82e1714c60 FOREIGN KEY (responsible_id) REFERENCES public.users(id);


--
-- Name: tasks fk_rails_9d099ad687; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_rails_9d099ad687 FOREIGN KEY (parent_task_id) REFERENCES public.tasks(id);


--
-- Name: recurrence_rules fk_rails_c71758e08e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurrence_rules
    ADD CONSTRAINT fk_rails_c71758e08e FOREIGN KEY (task_id) REFERENCES public.tasks(id);


--
-- Name: task_occurrences fk_rails_d0f407eed0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_occurrences
    ADD CONSTRAINT fk_rails_d0f407eed0 FOREIGN KEY (task_id) REFERENCES public.tasks(id);


--
-- Name: tasks fk_rails_f3b70736bf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_rails_f3b70736bf FOREIGN KEY (delegated_user_id) REFERENCES public.users(id);


--
-- Name: task_tags fk_rails_f7e1d90bfc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_tags
    ADD CONSTRAINT fk_rails_f7e1d90bfc FOREIGN KEY (tag_id) REFERENCES public.tags(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260518000001'),
('20260515000001'),
('20260514000007'),
('20260514000006'),
('20260514000005'),
('20260514000004'),
('20260514000003'),
('20260514000002'),
('20260514000001'),
('20260512000004'),
('20260512000003'),
('20260512000002'),
('20260512000001');

