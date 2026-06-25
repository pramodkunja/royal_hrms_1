/** Reusable circular initials avatar. Pass `color` for a department-tinted background. */
export default function Avatar({
  text,
  size = 36,
  color,
  className = "",
}: {
  text: string;
  size?: number;
  color?: string;
  className?: string;
}) {
  return (
    <div
      className={`rounded-full text-white flex items-center justify-center font-semibold flex-shrink-0 ${color ? "" : "bg-[var(--primary)]"} ${className}`}
      style={{
        width: size,
        height: size,
        fontSize: Math.round(size * 0.36),
        ...(color ? { backgroundColor: color } : {}),
      }}
    >
      {text}
    </div>
  );
}
