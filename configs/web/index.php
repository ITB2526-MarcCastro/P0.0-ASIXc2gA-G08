<?php
$host = "192.168.20.10";
$user = "bchecker";
$pass = "bchecker121";
$db   = "equipaments";

mysqli_report(MYSQLI_REPORT_OFF);
$conn = @new mysqli($host, $user, $pass, $db);
$conn->set_charset("utf8mb4");
?>
<!DOCTYPE html>
<html lang="ca">
<head>
<meta charset="UTF-8">
<title>Equipaments d'educació de Barcelona</title>
<style>
  body { font-family: sans-serif; margin: 2rem; }
  table { border-collapse: collapse; width: 100%; }
  th, td { border: 1px solid #ccc; padding: 6px 10px; text-align: left; }
  th { background: #0033cc; color: #fff; }
  tr:nth-child(even) { background: #f3f3f3; }
  .ok { color: green; } .ko { color: red; }
</style>
</head>
<body>
<h1>Equipaments d'educació de Barcelona</h1>
<?php
if ($conn->connect_errno) {
    echo "<p class='ko'>Error de connexió amb la BBDD: " . htmlspecialchars($conn->connect_error) . "</p>";
    exit;
}
echo "<p class='ok'>Connectat a " . htmlspecialchars($host) . " des de " . htmlspecialchars(gethostname()) . "</p>";

$total = $conn->query("SELECT COUNT(DISTINCT register_id) AS n FROM equipaments")->fetch_assoc()['n'];
echo "<p>Equipaments únics: <strong>$total</strong></p>";

$res = $conn->query("SELECT register_id, MAX(name) AS name, MAX(addresses_road_name) AS carrer,
                            MAX(addresses_neighborhood_name) AS barri, MAX(addresses_district_name) AS districte
                     FROM equipaments GROUP BY register_id ORDER BY name LIMIT 100");
?>
<table>
<tr><th>ID</th><th>Nom</th><th>Carrer</th><th>Barri</th><th>Districte</th></tr>
<?php while ($r = $res->fetch_assoc()): ?>
<tr>
  <td><?= htmlspecialchars($r['register_id']) ?></td>
  <td><?= htmlspecialchars($r['name']) ?></td>
  <td><?= htmlspecialchars($r['carrer']) ?></td>
  <td><?= htmlspecialchars($r['barri']) ?></td>
  <td><?= htmlspecialchars($r['districte']) ?></td>
</tr>
<?php endwhile; ?>
</table>
<p><small>Mostrant els primers 100 resultats.</small></p>
</body>
</html>
