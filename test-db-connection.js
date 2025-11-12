// Test database connection
require('dotenv').config();
const { PrismaClient } = require('@prisma/client');

console.log('Testing database connection...');
console.log('DATABASE_PROVIDER:', process.env.DATABASE_PROVIDER);
console.log('DATABASE_CONNECTION_URI:', process.env.DATABASE_CONNECTION_URI ? 
  process.env.DATABASE_CONNECTION_URI.substring(0, 50) + '...' : 'NOT SET');

// Set DATABASE_URL if DATABASE_CONNECTION_URI is set (Prisma compatibility)
if (!process.env.DATABASE_URL && process.env.DATABASE_CONNECTION_URI) {
  process.env.DATABASE_URL = process.env.DATABASE_CONNECTION_URI;
  console.log('Mapped DATABASE_CONNECTION_URI to DATABASE_URL');
}

const prisma = new PrismaClient({
  log: ['error', 'warn'],
});

async function testConnection() {
  try {
    console.log('\nAttempting to connect...');
    await prisma.$connect();
    console.log('✅ Database connection successful!');
    
    // Try a simple query
    const result = await prisma.$queryRaw`SELECT version()`;
    console.log('✅ Database query successful!');
    console.log('PostgreSQL version:', result[0]?.version || 'Unknown');
    
    await prisma.$disconnect();
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Database connection failed:');
    console.error('Error code:', error.code);
    console.error('Error message:', error.message);
    console.error('\nFull error:', error);
    
    // Common error solutions
    if (error.message.includes('Tenant or user not found')) {
      console.error('\n🔍 Troubleshooting:');
      console.error('1. Check if your Supabase project is active (not paused)');
      console.error('2. Verify the database password is correct');
      console.error('3. Check if the database user exists');
      console.error('4. Try using the direct connection (not pooler):');
      console.error('   Change port from 6543 (pooler) to 5432 (direct)');
    }
    
    if (error.message.includes('password authentication failed')) {
      console.error('\n🔍 Troubleshooting:');
      console.error('1. The database password might be incorrect');
      console.error('2. Check your Supabase project settings');
    }
    
    if (error.message.includes('does not exist')) {
      console.error('\n🔍 Troubleshooting:');
      console.error('1. The database might not exist');
      console.error('2. Check your Supabase project');
    }
    
    await prisma.$disconnect().catch(() => {});
    process.exit(1);
  }
}

testConnection();

