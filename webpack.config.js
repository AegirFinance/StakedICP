const path = require("path");
const webpack = require("webpack");
const HtmlWebpackPlugin = require("html-webpack-plugin");
const TerserPlugin = require("terser-webpack-plugin");
const CopyPlugin = require("copy-webpack-plugin");

let canisters = {};

function network() {
  return process.env.DFX_NETWORK ||
    (process.env.NODE_ENV === "production" ? "ic" : "local");
}


function initCanisterIds() {
  const net = network();

  const staticIds = require(path.resolve("canister_ids.json"));
  for (const canister in staticIds) {
    canisters[canister] = staticIds[canister][net];
  }

  var idsPath = net === "ic" ? path.resolve("canister_ids.json") : path.resolve(".dfx", net, "canister_ids.json");
  try {
    const loadedIds = require(idsPath);
    for (const canister in loadedIds) {
      canisters[canister] = loadedIds[canister][net];
    }
  } catch (error) {
    throw new Error(`Could not find ${idsPath}:`, error);
  }
  for (const canister in canisters) {
    process.env["CANISTER_ID_"+canister.toUpperCase().replace("-", "_")] = canisters[canister];
  }
}
initCanisterIds();

const isDevelopment = process.env.NODE_ENV !== "production";
const asset_entry = path.join(
  "src",
  "website",
  "src",
  "index.html"
);

module.exports = {
  target: "web",
  mode: isDevelopment ? "development" : "production",
  entry: {
    // The frontend.entrypoint points to the HTML file for this build, so we need
    // to replace the extension to `.js`.
    index: path.join(__dirname, asset_entry).replace(/\.html$/, ".tsx"),
  },
  devtool: isDevelopment ? "source-map" : false,
  optimization: {
    minimize: !isDevelopment,
    minimizer: [new TerserPlugin()],
  },
  resolve: {
    extensions: [".js", ".ts", ".jsx", ".tsx"],
    fallback: {
      assert: require.resolve("assert/"),
      buffer: require.resolve("buffer/"),
      events: require.resolve("events/"),
      stream: require.resolve("stream-browserify/"),
      util: require.resolve("util/"),
    },
  },
  output: {
    filename: "index.js",
    path: path.join(__dirname, "dist", "website"),
  },

  // Depending in the language or framework you are using for
  // front-end development, add module loaders to the default
  // webpack configuration. For example, if you are using React
  // modules and CSS as described in the "Adding a stylesheet"
  // tutorial, uncomment the following lines:
  module: {
   rules: [
     { test: /\.(ts|tsx|jsx)$/, loader: "ts-loader" },
     { test: /\.css$/, use: ['style-loader','css-loader'] }
   ]
  },
  plugins: [
    new HtmlWebpackPlugin({
      template: path.join(__dirname, asset_entry),
      cache: false
    }),
    new CopyPlugin({
      patterns: [
        {
          from: path.join(__dirname, "src", "website", "public"),
          to: path.join(__dirname, "dist", "website"),
        },
      ],
    }),
    new webpack.EnvironmentPlugin({
      NETWORK: network() == "local" ? "http://localhost:8080" : "https://icp-api.io",
      CANISTER_ID_DEPOSITS: canisters["deposits"],
      CANISTER_ID_NNS_LEDGER: canisters["nns-ledger"],
      CANISTER_ID_TOKEN: canisters["token"],
    }),
    new webpack.ProvidePlugin({
      Buffer: [require.resolve("buffer/"), "Buffer"],
      process: require.resolve("process/browser"),
    }),
  ],
  // proxy /api to port 8080 during development
  devServer: {
    port: 3000,
    proxy: {
      "/api": {
        target: "http://localhost:8080",
        changeOrigin: true,
        pathRewrite: {
          "^/api": "/api",
        },
      },
    },
    hot: true,
    historyApiFallback: true,
    contentBase: path.resolve(__dirname, "./src/website"),
    watchContentBase: true
  },
};
