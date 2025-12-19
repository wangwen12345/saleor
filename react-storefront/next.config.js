/** @type {import('next').NextConfig} */
const config = {
	images: {
		remotePatterns: [
			{ protocol: "http", hostname: "host.docker.internal" },
			{ protocol: "http", hostname: "localhost" },
			{ protocol: "https", hostname: "*" },
		],
	},
	experimental: {
		typedRoutes: false,
	},
	// used in the Dockerfile
	output:
		process.env.NEXT_OUTPUT === "standalone"
			? "standalone"
			: process.env.NEXT_OUTPUT === "export"
			  ? "export"
			  : undefined,
};

export default config;
