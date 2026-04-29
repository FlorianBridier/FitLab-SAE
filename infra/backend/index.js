const express = require("express");
const cors = require("cors");

const { supabase } = require("./supabaseClient");
const auth = require("./middleware/auth");
const requireRole = require("./middleware/requireRole");

const app = express();
const PORT = process.env.BACKEND_PORT || process.env.PORT || 3000;

// ================================================================
// Middlewares globaux
// ================================================================
app.use(express.json());

app.use(
  cors({
    origin: "*", // en prod tu pourras restreindre à ton domaine front
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

// ================================================================
// Routes publiques (SANS /api, car Nginx enlève le prefixe /api)
// ================================================================
app.get("/api/health", (req, res) => {
  const supabaseConfigured = !!(
    process.env.SUPABASE_URL && process.env.SUPABASE_KEY
  );

  res.json({
    status: "ok",
    supabaseConfigured,
  });
});

app.get("/api/news/latest", async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("news")
      .select("*")                     // on prend toutes les colonnes pour simplifier
      .order("created_at", { ascending: false })
      .limit(3);

    if (error) {
      console.error("Supabase /news/latest error:", error);
      // TEMPORAIREMENT on renvoie les détails pour comprendre
      return res.status(500).json({
        error: "Supabase error in /news/latest",
        message: error.message,
        details: error.details,
        hint: error.hint,
        code: error.code,
      });
    }

    res.json({ news: data || [] });
  } catch (err) {
    console.error("Unexpected /news/latest error:", err);
    return res.status(500).json({
      error: "Unexpected error in /news/latest",
      message: err.message,
    });
  }
});


// ================================================================
// Routes protégées (JWT obligatoire)
// (toujours sans /api, Nginx garde le prefixe pour lui)
// ================================================================
app.get("/api/me", auth, async (req, res) => {
  try {
    // On va chercher le rôle dans la table public.users
    const { data, error } = await supabase
      .from("users")
      .select("role")
      .eq("user_id", req.user.id)
      .single();

    let roleFromDb = null;

    if (error) {
      console.error("Erreur Supabase /me (users):", error);
    } else {
      roleFromDb = data?.role || null;
    }

    const roleFromMeta =
      (req.user.app_metadata && req.user.app_metadata.role) ||
      (req.user.user_metadata && req.user.user_metadata.role) ||
      null;

    res.json({
      id: req.user.id,
      email: req.user.email,
      role: roleFromDb || roleFromMeta || "unknown",
    });
  } catch (err) {
    console.error("Erreur /me:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});


app.get("/users", auth, requireRole(["admin"]), async (req, res) => {
  try {
    const { data, error } = await supabase.from("profiles").select("*");

    if (error) {
      console.error("Supabase /users error:", error);
      return res.status(500).json({ error: "Failed to fetch users" });
    }

    res.json({ users: data || [] });
  } catch (err) {
    console.error("Unexpected /users error:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});

// -----------------------------------------------------------------------------
// Route admin : /admin/stats (protégée par JWT + rôle admin)
// -----------------------------------------------------------------------------
app.get("/admin/stats", auth, requireRole(["admin"]), async (req, res) => {
  try {
    // Nombre d'utilisateurs dans ta table public.users
    const { count: usersCount, error: usersError } = await supabase
      .from("users")
      .select("*", { count: "exact", head: true });

    if (usersError) throw usersError;

    // Nombre de news (ici tu peux filtrer "archive = false" si tu veux)
    const { count: newsCount, error: newsError } = await supabase
      .from("news")
      .select("*", { count: "exact", head: true });

    if (newsError) throw newsError;

    res.json({
      usersCount: usersCount ?? 0,
      newsCount: newsCount ?? 0,
      // goalsCount: ...,   // tu pourras les rajouter plus tard
      // badgesCount: ...,
    });
  } catch (err) {
    console.error("Supabase /admin/stats error:", err);
    res.status(500).json({ error: "Failed to fetch admin stats" });
  }
});

// -----------------------------------------------------------------------------
// Route admin : liste des utilisateurs
// GET /api/admin/users
// -----------------------------------------------------------------------------
app.get("/api/admin/users", auth, requireRole(["admin"]), async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("users")
      .select(
        "user_id, name, email, role, created_at, subscription_tier, goal, coach_id"
      )
      .order("created_at", { ascending: false });

    if (error) {
      console.error("Supabase /admin/users error:", error);
      return res.status(500).json({ error: "Failed to fetch users" });
    }

    res.json({ users: data || [] });
  } catch (err) {
    console.error("Unexpected /admin/users error:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});




// ================================================================
// Démarrage
// ================================================================
app.listen(PORT, () => {
  console.log(`✅ Backend listening on port ${PORT}`);
});
