const EMBED_DIM = 8;

function mockEmbed(text, dim = EMBED_DIM) {
  const vec = new Array(dim).fill(0);
  const bytes = Buffer.from(text, "utf-8");
  for (let i = 0; i < bytes.length; i++) {
    vec[i % dim] += bytes[i] * (1 + i * 0.01);
  }
  let total = 0;
  for (let i = 0; i < dim; i++) total += vec[i] * vec[i];
  total = Math.sqrt(total) || 1;
  for (let i = 0; i < dim; i++) vec[i] /= total;
  const buf = Buffer.allocUnsafe(dim * 4);
  for (let i = 0; i < dim; i++) buf.writeFloatLE(vec[i], i * 4);
  return buf.toString("hex").toUpperCase();
}

const users = [
  [1, "Sam", "Admin"],
  [2, "Oggy", "User"],
  [3, "Jack", "Editor"],
  [4, "Olivia", "Moderator"],
  [5, "Evee", "Guest"],
];

const queryNames = ["Admin", "User", "Editor", "Moderator", "Guest"];

const out = [];

out.push("CREATE TABLE users ( id INTEGER, name TEXT, role TEXT );");
for (const [id, name, role] of users) {
  out.push(`INSERT INTO users VALUES (${id}, '${name.replace(/'/g, "''")}', '${role.replace(/'/g, "''")}');`);
}

out.push("CREATE VIRTUAL TABLE user_vec USING vec0(embedding float[8]);");
for (const [id, name, role] of users) {
  const hex = mockEmbed(`${name} ${role}`);
  out.push(`INSERT INTO user_vec(rowid, embedding) VALUES (${id}, X'${hex}');`);
}

out.push("CREATE TABLE query_vectors ( name TEXT PRIMARY KEY, embedding BLOB );");
for (const name of queryNames) {
  const hex = mockEmbed(name);
  out.push(`INSERT INTO query_vectors(name, embedding) VALUES ('${name.replace(/'/g, "''")}', X'${hex}');`);
}

process.stdout.write(out.join("\n") + "\n");