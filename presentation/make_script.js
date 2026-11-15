// Turn speaker_script.js into a printable script (LaTeX -> PDF via tectonic)
// and a plain Markdown copy.  Usage: node presentation/make_script.js
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");
const S = require("./speaker_script.js");
const DIR = __dirname;

const tex = (s) => s.replace(/\\/g, "\\textbackslash{}").replace(/([&%$#_{}])/g, "\\$1")
  .replace(/×/g, "$\\times$").replace(/−/g, "--").replace(/—/g, "---").replace(/→/g, "$\\rightarrow$")
  .replace(/~/g, "\\textasciitilde{}").replace(/\^/g, "\\textasciicircum{}");

const toSec = (t) => { const [m, s] = t.split(":").map(Number); return m * 60 + s; };
const total = S.reduce((a, x) => a + toSec(x.time), 0);
const mmss = (sec) => `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, "0")}`;

// who speaks where
const order = [];
S.forEach((x, i) => {
  const last = order[order.length - 1];
  if (last && last.who === x.speaker) last.to = i + 1; else order.push({ who: x.speaker, from: i + 1, to: i + 1 });
});

let L = [];
L.push(String.raw`\documentclass[11pt,a4paper]{article}
\usepackage[margin=2cm]{geometry}
\usepackage{xcolor,tcolorbox,parskip,booktabs,enumitem}
\usepackage{fontspec}
\setmainfont{Arial}
\definecolor{ink}{HTML}{0F2A3D}\definecolor{teal}{HTML}{1B998B}\definecolor{amber}{HTML}{C9781F}\definecolor{tint}{HTML}{EAF4F3}
\pagestyle{plain}
\begin{document}
{\color{ink}\LARGE\bfseries Presentation Script}\\[2pt]
{\large Systolic Array Matrix Multiplication Accelerator}\\[2pt]
{\color{teal}Team DnD \,·\, Project 12, Modern Computer Architecture}

\medskip
Total speaking time: about \textbf{${mmss(total)} min} for ${S.length} slides, plus questions.
Read each part in your own words. The \textcolor{amber}{\bfseries On the slide} line tells you what to point at.

\medskip
\begin{tabular}{@{}lll@{}}\toprule \textbf{Speaker} & \textbf{Slides} & \textbf{Hand over to} \\ \midrule`);
order.forEach((o, k) => L.push(`${tex(o.who)} & ${o.from === o.to ? o.from : o.from + "--" + o.to} & ${k + 1 < order.length ? tex(order[k + 1].who) : "Questions"} \\\\`));
L.push(String.raw`\bottomrule\end{tabular}
`);
S.forEach((x, i) => {
  L.push(String.raw`\begin{tcolorbox}[colback=tint,colframe=tint,boxrule=0pt,arc=2mm,left=3mm,right=3mm,top=2mm,bottom=2mm]`);
  L.push(`{\\color{ink}\\bfseries Slide ${i + 1}: ${tex(x.title)}}\\\\[1pt]{\\small\\color{teal}\\bfseries ${tex(x.speaker)} \\,·\\, about ${x.time} min}`);
  L.push("\\end{tcolorbox}\\vspace{-2pt}");
  x.script.forEach((p) => L.push(tex(p) + "\n"));
  L.push(`{\\small\\color{amber}\\bfseries On the slide:}{\\small\\ ${tex(x.point)}}\n\\bigskip\n`);
});
L.push(String.raw`\newpage{\color{ink}\Large\bfseries Likely questions and short answers}\par\medskip
\begin{enumerate}[leftmargin=*,itemsep=6pt]`);
S.qa.forEach(([q, a]) => L.push(`\\item \\textbf{${tex(q)}}\\\\ ${tex(a)}`));
L.push("\\end{enumerate}\n\\end{document}\n");
fs.writeFileSync(path.join(DIR, "speaker_script.tex"), L.join("\n"));
execSync("tectonic -X compile speaker_script.tex", { cwd: DIR, stdio: "inherit" });
fs.renameSync(path.join(DIR, "speaker_script.pdf"), path.join(DIR, "DnD_Presentation_Script.pdf"));

// Markdown copy
let M = [`# Presentation Script — Team DnD`, ``, `Systolic Array Matrix Multiplication Accelerator · Project 12, Modern Computer Architecture`, ``,
  `Total speaking time: about **${mmss(total)} min** for ${S.length} slides, plus questions.`, ``,
  `| Speaker | Slides |`, `|---|---|`, ...order.map((o) => `| ${o.who} | ${o.from === o.to ? o.from : o.from + "–" + o.to} |`), ``];
S.forEach((x, i) => {
  M.push(`## Slide ${i + 1}: ${x.title}`, ``, `**${x.speaker}** · about ${x.time} min`, ``);
  x.script.forEach((p) => M.push(p, ``));
  M.push(`*On the slide:* ${x.point}`, ``);
});
M.push(`## Likely questions`, ``);
S.qa.forEach(([q, a]) => M.push(`**${q}**  `, a, ``));
fs.writeFileSync(path.join(DIR, "DnD_Presentation_Script.md"), M.join("\n"));
console.log("total", mmss(total));
