const { supabase } = require("../supabaseClient");

function requireRole(allowedRoles = []) {
  return async (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: "Not authenticated" });
    }

    // 1) On essaie d'abord via app_metadata / user_metadata
    let role =
      (req.user.app_metadata && req.user.app_metadata.role) ||
      (req.user.user_metadata && req.user.user_metadata.role) ||
      null;

    try {
      // 2) Si pas de rôle trouvé, on va le chercher dans la table public.users
      if (!role) {
        const { data, error } = await supabase
          .from("users")
          .select("role")
          .eq("user_id", req.user.id)
          .single();

        if (error) {
          console.error("Erreur Supabase requireRole(users):", error);
          return res
            .status(500)
            .json({ error: "Failed to fetch user role from database" });
        }

        role = data?.role || null;
      }

      // 3) Si toujours pas de rôle ou rôle pas autorisé → 403
      if (!role || !allowedRoles.includes(role)) {
        return res.status(403).json({ error: "Forbidden: insufficient role" });
      }

      req.role = role;
      next();
    } catch (err) {
      console.error("Unexpected requireRole error:", err);
      return res
        .status(500)
        .json({ error: "Unexpected error while checking role" });
    }
  };
}

module.exports = requireRole;
