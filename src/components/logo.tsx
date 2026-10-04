import { cn } from "@/lib/utils"

/**
 * Jorts & Co. logo, redrawn as strokes from the original artwork.
 * Uses currentColor, so it follows the text colour (works on dark backgrounds).
 */
export function Logo({ className, title = "Jorts & Co." }: { className?: string; title?: string }) {
  return (
    <svg
      viewBox="54 31 360 196"
      role="img"
      aria-label={title}
      className={cn("h-auto", className)}
      fill="none"
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <title>{title}</title>
      <ellipse cx="233.5" cy="128.5" rx="174" ry="92" strokeWidth="5" />
      <g strokeWidth="8.8">
        {/* J */}
        <path d="M108,84 L153,83" />
        <path d="M151,85 L151.5,128 C152,146 140,155.5 124,155.5 C112,155.5 103,150 99,143" />
        {/* o */}
        <ellipse cx="196.5" cy="131" rx="20.5" ry="18" />
        {/* r */}
        <path d="M237,114 L238,146" />
        <path d="M238,125 C241,115 249,111 256,111 C262,111 266,113 267,117" />
        {/* t */}
        <path d="M281,84 L283,124 C284,138 289,146 298,146 C305,146 310,141 312,137" />
        <path d="M263,98 L305,95" />
        {/* s */}
        <path d="M354,109 C349,105 337,104 332,110 C328,117 337,121 345,124.5 C353,128 358,132 356,139 C353,147 337,148 330,139" />
      </g>
      <circle cx="373.5" cy="143.5" r="3.4" fill="currentColor" stroke="none" />
      <g strokeWidth="2.6">
        {/* & */}
        <path d="M315.5,187.5 L306.5,178 C302.5,174 303,169.8 306,169.8 C309.2,169.8 310,172.8 308,175.5 L304.5,180 C301.5,184 302.5,187.8 306.5,187.8 C310.5,187.8 313,184 313.8,179" />
        {/* C */}
        <path d="M330.5,173 C328.5,170 323.5,170.3 321.5,174 C319.5,178 320,184.5 322.5,186.8 C325,189 329,188 331,185.5" />
        {/* o */}
        <ellipse cx="340" cy="181.6" rx="4.3" ry="5.6" />
      </g>
      <circle cx="350" cy="186.6" r="1.7" fill="currentColor" stroke="none" />
    </svg>
  )
}
