{
  description = "Galois Prover Benchmarking";

  inputs = {
    union.url =
      "github:unionlabs/union/6a2dcde5092b7169459526b29b15bf9ae942df39";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, union }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        mkGaloisd = { maxVal }:
          union.packages.${system}.galoisd;
      in {
        packages = {
          benchmark =
            let galois-universal = mkGaloisd { maxVal = 16; };
                valset = [ 4 8 16 32 64 128 ];
          in pkgs.writeScriptBin "galois-benchmark" ''
            #!/usr/bin/env nix-shell
            #!nix-shell --pure -i runghc -p "haskellPackages.ghcWithPackages (pkgs: with pkgs; [ turtle criterion text bytestring foldl Chart Chart-diagrams aeson aeson-casing unordered-containers ])"

            {-# OPTIONS_GHC -fno-warn-tabs #-}
            {-# LANGUAGE OverloadedStrings #-}
            {-# LANGUAGE TypeApplications #-}

            import Turtle
            import Criterion.Main
            import Control.Concurrent
            import Data.Int
            import qualified Data.Text as T
            import qualified Control.Foldl as F
            import Graphics.Rendering.Chart.Easy
            import Graphics.Rendering.Chart.Backend.Diagrams
            import Data.Aeson hiding ((.=))
            import Data.Aeson.Casing
            import GHC.Generics
            import qualified Data.ByteString.Lazy as BS
            import Data.Either
            import Data.IORef
            import qualified Data.HashMap.Strict as M

            data VariableStats =
              VariableStats {
                csNbInternalVariables :: Int,
                csNbSecretVariables :: Int,
                csNbPublicVariables :: Int,
                csNbConstraints :: Int,
                csNbCoefficients :: Int
              }
              deriving (Show, Generic)

            instance ToJSON VariableStats where
               toJSON = genericToJSON $ aesonPrefix snakeCase

            instance FromJSON VariableStats where
               parseJSON = genericParseJSON $ aesonPrefix snakeCase

            data ProvingKeyStats =
              ProvingKeyStats {
                pkNbG1 :: Int,
                pkNbG2 :: Int
              }
              deriving (Show, Generic)

            instance ToJSON ProvingKeyStats where
               toJSON = genericToJSON $ aesonPrefix snakeCase

            instance FromJSON ProvingKeyStats where
               parseJSON = genericParseJSON $ aesonPrefix snakeCase

            data VerifyingKeyStats =
              VerifyingKeyStats {
                vkNbG1 :: Int,
                vkNbG2 :: Int,
                vkNbPublicWitness :: Int
              }
              deriving (Show, Generic)

            instance ToJSON VerifyingKeyStats where
               toJSON = genericToJSON $ aesonPrefix snakeCase

            instance FromJSON VerifyingKeyStats where
               parseJSON = genericParseJSON $ aesonPrefix snakeCase

            data CircuitStats =
              CircuitStats {
                circuitVariableStats :: VariableStats,
                circuitProvingKeyStats :: ProvingKeyStats,
                circuitVerifyingKeyStats :: VerifyingKeyStats
              }
              deriving (Show, Generic)

            instance ToJSON CircuitStats where
               toJSON = genericToJSON $ aesonPrefix snakeCase

            instance FromJSON CircuitStats where
               parseJSON = genericParseJSON $ aesonPrefix snakeCase

            generateConstraints :: M.HashMap Int CircuitStats -> IO ()
            generateConstraints stats = toFile def "constraints.svg" $ do
              layout_title .= "Circuit Constraints"
              layout_x_axis . laxis_title .= "validators (max)"
              setColors [opaque blue]
              plot (points "constraints" (M.toList (csNbConstraints . circuitVariableStats <$> stats)))

            generateCoefficients :: M.HashMap Int CircuitStats -> IO ()
            generateCoefficients stats = toFile def "coefficients.svg" $ do
              layout_title .= "Circuit Coefficients"
              layout_x_axis . laxis_title .= "validators (max)"
              setColors [opaque blue]
              plot (points "coefficients" (M.toList (csNbCoefficients . circuitVariableStats <$> stats)))

            generateInputs :: M.HashMap Int CircuitStats -> IO ()
            generateInputs stats = toFile def "inputs.svg" $ do
              layout_title .= "Circuit Inputs"
              layout_x_axis . laxis_title .= "validators (max)"
              layout_y_axis . laxis_title .= "variables"
              setColors [opaque blue, opaque red]
              plot (points "public" (M.toList (csNbPublicVariables . circuitVariableStats <$> stats)))
              plot (points "secret" (M.toList (csNbSecretVariables . circuitVariableStats <$> stats)))

            generatePK :: M.HashMap Int CircuitStats -> IO ()
            generatePK stats = toFile def "pk.svg" $ do
              layout_title .= "Proving Key Points"
              layout_x_axis . laxis_title .= "validators (max)"
              layout_y_axis . laxis_title .= "points"
              setColors [opaque blue, opaque red]
              plot (points "G1" (M.toList (pkNbG1 . circuitProvingKeyStats <$> stats)))
              plot (points "G2" (M.toList (pkNbG2 . circuitProvingKeyStats <$> stats)))

            generateVK :: M.HashMap Int CircuitStats -> IO ()
            generateVK stats = toFile def "vk.svg" $ do
              layout_title .= "Verifying Key Points"
              layout_x_axis . laxis_title .= "validators (max)"
              layout_y_axis . laxis_title .= "points"
              setColors [opaque blue, opaque red]
              plot (points "G1" (M.toList (vkNbG1 . circuitVerifyingKeyStats <$> stats)))
              plot (points "G2" (M.toList (vkNbG2 . circuitVerifyingKeyStats <$> stats)))

            generatePublicWitness :: M.HashMap Int CircuitStats -> IO ()
            generatePublicWitness stats = toFile def "witness.svg" $ do
              layout_title .= "Verifying Key Public Witnesses"
              layout_x_axis . laxis_title .= "validators"
              setColors [opaque blue]
              plot (points "number of public witness" (M.toList (vkNbPublicWitness . circuitVerifyingKeyStats <$> stats)))

            queryStats :: IO CircuitStats
            queryStats = do
              r <- fold (inproc "${pkgs.lib.getExe galois-universal}" ["query-stats", "localhost:8080"] empty) F.head
              case r of
                Just l -> pure $ either error id $ eitherDecode @CircuitStats $ fromString $ T.unpack $ lineToText l
                _ -> error "should be able to query"

            ${builtins.concatStringsSep "\n" (builtins.map (maxVal:
              let galois = pkgs.lib.getExe (mkGaloisd { inherit maxVal; });
              in ''
                serve${builtins.toString maxVal} allStats tmpdir = do
                  pkExists <- testpath "pk.bin"
                  when pkExists $ rm "pk.bin"
                  vkExists <- testpath "vk.bin"
                  when vkExists $ rm "vk.bin"
                  r1csExists <- testpath "r1cs.bin"
                  when r1csExists $ rm "r1cs.bin"
                  threadId <- forkIO $ stdout $ inproc "${galois}" ["serve", "localhost:8080"] empty
                  let rdy = do
                        code <- proc "${galois}" ["query-stats", "localhost:8080"] empty
                        case code of
                          ExitSuccess -> pure ()
                          ExitFailure _ -> do
                            echo "Awaiting for prover to be ready..."
                            sleep 10.0
                            rdy
                  rdy
                  stats <- queryStats
                  modifyIORef allStats $ M.insert (${builtins.toString maxVal} :: Int) stats
                  pure threadId

                prove${builtins.toString maxVal} =
                  stdout $ inproc "${galois}" ["example-prove", "localhost:8080", "${builtins.toString maxVal}"] empty
              '') valset)}

            main = do
              allStats <- newIORef M.empty
              runManaged $ do
                tmpdir <- mktempdir "/tmp" "galois-benchmark"
                previous <- pwd
                echo $ unsafeTextToLine $ "Moving to temporary directory: " <> T.pack (show tmpdir)
                cd tmpdir
                liftIO $
                  defaultMain [
                    bgroup "prove" [${
                      builtins.concatStringsSep ''
                        ,
                        	'' (builtins.map (maxVal:
                          ''
                            envWithCleanup (serve${
                              builtins.toString maxVal
                            } allStats tmpdir) (\threadId -> cd previous *> killThread threadId) (const $ bench "${
                              builtins.toString maxVal
                            } validators" (whnfIO prove${
                              builtins.toString maxVal
                            }))'') valset)
                    }]
                  ]
              actualStats <- readIORef allStats
              generateConstraints actualStats
              generateCoefficients actualStats
              generatePK actualStats
              generateVK actualStats
              generateInputs actualStats
              generatePublicWitness actualStats
          '';
        };
      });
}
