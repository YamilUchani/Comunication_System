-- SQL Database Schema for De Supervisor a Co-Aprendiz
-- Executable in Supabase SQL Editor

-- 1. Profiles Table (Linked to Supabase Auth Users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow individual read of profile" 
    ON public.profiles FOR SELECT 
    USING (auth.uid() = id);

CREATE POLICY "Allow individual update of profile" 
    ON public.profiles FOR UPDATE 
    USING (auth.uid() = id);


-- 2. Students Table
CREATE TABLE IF NOT EXISTS public.students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    grade_level VARCHAR(100) NOT NULL,
    avatar_code VARCHAR(10),
    avatar_color VARCHAR(50),
    gpa DECIMAL(5,2) DEFAULT 0.00,
    attendance DECIMAL(5,2) DEFAULT 100.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Parents can view their own students" 
    ON public.students FOR SELECT 
    USING (auth.uid() = parent_id);


-- 3. Teachers Table
CREATE TABLE IF NOT EXISTS public.teachers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    subject VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    color VARCHAR(50) DEFAULT '#6366f1'
);

ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read of teacher information" 
    ON public.teachers FOR SELECT 
    USING (true);


-- 4. Grades Table
CREATE TABLE IF NOT EXISTS public.grades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    subject VARCHAR(255) NOT NULL,
    score DECIMAL(5,2) NOT NULL,
    max_score DECIMAL(5,2) DEFAULT 100.00,
    date DATE DEFAULT CURRENT_DATE,
    category VARCHAR(255) NOT NULL, -- e.g., 'Exam 2', 'Homework 4'
    teacher_id UUID REFERENCES public.teachers(id) ON DELETE SET NULL,
    comments TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.grades ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Parents can view grades of their students" 
    ON public.grades FOR SELECT 
    USING (
        student_id IN (
            SELECT id FROM public.students WHERE parent_id = auth.uid()
        )
    );


-- 5. Tasks Table
CREATE TABLE IF NOT EXISTS public.tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    subject VARCHAR(255) NOT NULL,
    due_date DATE NOT NULL,
    status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'completed'
    difficulty VARCHAR(50) DEFAULT 'Medium', -- 'Low', 'Medium', 'High'
    resources JSONB DEFAULT '[]'::jsonb, -- Store dynamic array of video/pdf link paths
    discussions JSONB DEFAULT '[]'::jsonb, -- Store discussion strings
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Parents can select tasks of their students" 
    ON public.tasks FOR SELECT 
    USING (
        student_id IN (
            SELECT id FROM public.students WHERE parent_id = auth.uid()
        )
    );

CREATE POLICY "Parents can update task discussion boards"
    ON public.tasks FOR UPDATE
    USING (
        student_id IN (
            SELECT id FROM public.students WHERE parent_id = auth.uid()
        )
    );


-- 6. Chat Messages Table
CREATE TABLE IF NOT EXISTS public.chats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL, -- Either parent UUID or teacher UUID
    receiver_id UUID NOT NULL, 
    text TEXT NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;

-- Allow reading chats where active user is either sender or receiver
CREATE POLICY "Users can read their own chats" 
    ON public.chats FOR SELECT 
    USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can insert chats where they are sender" 
    ON public.chats FOR INSERT 
    WITH CHECK (auth.uid() = sender_id);


-- 7. Calendar Events Table
CREATE TABLE IF NOT EXISTS public.calendar_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL, -- 'meeting', 'homework', 'exam', 'class'
    event_date DATE NOT NULL,
    event_time VARCHAR(100) NOT NULL,
    note TEXT
);

ALTER TABLE public.calendar_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Parents can read/write their calendar events" 
    ON public.calendar_events FOR ALL 
    USING (auth.uid() = parent_id);


-- 8. Academic Rules Alerts Table
CREATE TABLE IF NOT EXISTS public.alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    type VARCHAR(50) DEFAULT 'warning',
    message TEXT NOT NULL,
    action VARCHAR(100),
    teacher_id UUID REFERENCES public.teachers(id) ON DELETE SET NULL,
    resolved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Parents can read/update alerts of their students" 
    ON public.alerts FOR ALL 
    USING (
        student_id IN (
            SELECT id FROM public.students WHERE parent_id = auth.uid()
        )
    );
