import Image from "next/image";

export function RasterLockup({ className = "" }: { className?: string }) {
  return (
    <span className={`inline-flex items-center ${className}`}>
      <Image
        src="/brand/raster-lockup-color.svg"
        alt=""
        width={126}
        height={32}
        className="h-auto w-full dark:hidden"
        priority
      />
      <Image
        src="/brand/raster-lockup-color-dark.svg"
        alt=""
        width={126}
        height={32}
        className="hidden h-auto w-full dark:block"
        priority
      />
      <span className="sr-only">Raster</span>
    </span>
  );
}

export function RasterMark({ className = "" }: { className?: string }) {
  return (
    <Image
      src="/brand/raster-mark-color.svg"
      alt="Raster"
      width={32}
      height={32}
      className={className}
      priority
    />
  );
}
