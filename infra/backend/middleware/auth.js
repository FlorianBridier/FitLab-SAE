const { supabase } = require("../supabaseClient");

async function auth(req, res, next) {
  const authHeader = req.headers["authorization"] || req.headers["Authorization"];

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ error: "Missing or invalid Authorization header" });
  }

  const token = authHeader.substring("Bearer ".length);

  try {
    const { data, error } = await supabase.auth.getUser(token);

    if (error || !data || !data.user) {
      console.error("Supabase auth error:", error);
      return res.status(401).json({ error: "Invalid token" });
    }

    // On met l'utilisateur Supabase dans la requête
    req.user = data.user;

    next();
  } catch (err) {
    console.error("Unexpected auth error:", err);
    return res.status(500).json({ error: "Auth internal error" });
  }
}

module.exports = auth;
