-- Safe Migration Script for Evolution API
-- This script checks for existing objects before creating them

-- Create Enums (only if they don't exist)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'InstanceConnectionStatus') THEN
        CREATE TYPE "InstanceConnectionStatus" AS ENUM ('open', 'close', 'connecting');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'DeviceMessage') THEN
        CREATE TYPE "DeviceMessage" AS ENUM ('ios', 'android', 'web', 'unknown', 'desktop');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'TypebotSessionStatus') THEN
        CREATE TYPE "TypebotSessionStatus" AS ENUM ('open', 'closed', 'paused');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'TriggerType') THEN
        CREATE TYPE "TriggerType" AS ENUM ('all', 'keyword');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'TriggerOperator') THEN
        CREATE TYPE "TriggerOperator" AS ENUM ('contains', 'equals', 'startsWith', 'endsWith');
    END IF;
END $$;

-- Note: Continue with table creation using similar IF NOT EXISTS patterns
-- For now, let's check what tables exist and create only missing ones

